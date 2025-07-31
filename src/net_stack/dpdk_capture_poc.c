/*
 * QuantumArb 2.0 - DPDK Proof-of-Concept
 *
 * File: src/net_stack/dpdk_capture_poc.c
 *
 * Description:
 * This is a basic DPDK application that demonstrates the fundamentals of kernel-bypass
 * networking. It initializes the DPDK Environment Abstraction Layer (EAL), configures
 * a single network port, and enters a loop to receive and process packets directly
 * from the NIC, bypassing the kernel's network stack for minimal latency.
 *
 * Compilation:
 * Assuming DPDK is installed and RTE_SDK/RTE_TARGET environment variables are set:
 * gcc -O3 -march=native -o dpdk_capture_poc dpdk_capture_poc.c \
 * -I${RTE_SDK}/include -L${RTE_SDK}/lib \
 * -lrte_eal -lrte_ethdev -lrte_mbuf -lrte_mempool -lrte_net
 *
 * Execution:
 * The application requires hugepages and a DPDK-compatible NIC bound to the igb_uio
 * or vfio-pci driver.
 * sudo ./dpdk_capture_poc -l 1 -n 4 -- -p 0x1
 *
 * Arguments:
 * -l 1: Run on logical core 1.
 * -n 4: Use 4 memory channels.
 * --: Separates EAL arguments from application arguments.
 * -p 0x1: A bitmask indicating that port 0 should be used by the application.
 */

#include <stdio.h>
#include <stdint.h>
#include <inttypes.h>
#include <rte_eal.h>
#include <rte_ethdev.h>
#include <rte_cycles.h>
#include <rte_lcore.h>
#include <rte_mbuf.h>
#include <rte_ether.h>

#define RX_RING_SIZE 1024       // Size of the receive ring
#define NUM_MBUFS 8191          // Number of mbufs in the memory pool
#define MBUF_CACHE_SIZE 250     // Size of the per-core mbuf cache
#define BURST_SIZE 32           // Number of packets to process in a single burst

// --- Main Application Logic ---
int main(int argc, char *argv[]) {
    struct rte_mempool *mbuf_pool;
    uint16_t portid;
    int ret;
    unsigned nb_ports;
    struct rte_eth_conf port_conf_default = {
        .rxmode = { .max_lro_pkt_size = RTE_ETHER_MAX_LEN }
    };

    // --- 1. Initialize the Environment Abstraction Layer (EAL) ---
    // This initializes DPDK, parses command line args, and discovers hardware.
    ret = rte_eal_init(argc, argv);
    if (ret < 0) {
        rte_exit(EXIT_FAILURE, "Error with EAL initialization\n");
    }
    argc -= ret;
    argv += ret;

    // --- 2. Check for available Ethernet ports ---
    nb_ports = rte_eth_dev_count_avail();
    if (nb_ports == 0) {
        rte_exit(EXIT_FAILURE, "Error: No Ethernet ports found\n");
    }
    printf("Found %u available ports\n", nb_ports);

    // For this POC, we will use the first available port (port 0)
    portid = 0;

    // --- 3. Create a memory pool (mempool) for packet buffers (mbufs) ---
    // Mbufs are structures that hold network packet data. The mempool is a pre-allocated
    // pool of these structures to avoid costly memory allocation at runtime.
    mbuf_pool = rte_pktmbuf_pool_create("MBUF_POOL", NUM_MBUFS,
        MBUF_CACHE_SIZE, 0, RTE_MBUF_DEFAULT_BUF_SIZE, rte_socket_id());
    if (mbuf_pool == NULL) {
        rte_exit(EXIT_FAILURE, "Cannot create mbuf pool\n");
    }
    printf("Mempool created successfully.\n");

    // --- 4. Configure the Ethernet device ---
    const uint16_t rx_queues = 1;
    const uint16_t tx_queues = 0; // We are only receiving in this POC
    struct rte_eth_conf port_conf = port_conf_default;
    ret = rte_eth_dev_configure(portid, rx_queues, tx_queues, &port_conf);
    if (ret != 0) {
        rte_exit(EXIT_FAILURE, "Cannot configure Ethernet device\n");
    }

    // --- 5. Setup the Receive (Rx) Queue ---
    // We need to set up at least one receive queue for the port to receive packets.
    ret = rte_eth_rx_queue_setup(portid, 0, RX_RING_SIZE,
        rte_eth_dev_socket_id(portid), NULL, mbuf_pool);
    if (ret < 0) {
        rte_exit(EXIT_FAILURE, "Cannot setup RX queue\n");
    }
    printf("RX queue setup successfully.\n");

    // --- 6. Start the Ethernet port ---
    // This enables the device and allows it to start receiving packets.
    ret = rte_eth_dev_start(portid);
    if (ret < 0) {
        rte_exit(EXIT_FAILURE, "Cannot start Ethernet port\n");
    }
    printf("Port %u started successfully.\n", portid);

    // Enable promiscuous mode to capture all traffic on the interface
    ret = rte_eth_promiscuous_enable(portid);
    if (ret != 0) {
        rte_exit(EXIT_FAILURE, "Cannot enable promiscuous mode\n");
    }
    printf("Promiscuous mode enabled.\n\n");
    printf("--- Starting Packet Capture Loop ---\n");


    // --- 7. Main Packet Processing Loop ---
    // This loop continuously polls the NIC's receive queue for new packets.
    while (1) {
        struct rte_mbuf *bufs[BURST_SIZE];
        const uint16_t nb_rx = rte_eth_rx_burst(portid, 0, bufs, BURST_SIZE);

        if (unlikely(nb_rx == 0)) {
            // No packets received, continue polling
            continue;
        }

        // Process the burst of received packets
        for (uint16_t i = 0; i < nb_rx; i++) {
            struct rte_mbuf *m = bufs[i];
            struct rte_ether_hdr *eth_hdr;

            eth_hdr = rte_pktmbuf_mtod(m, struct rte_ether_hdr *);

            printf("Packet received: Port=%u, Src MAC: %02X:%02X:%02X:%02X:%02X:%02X, Dst MAC: %02X:%02X:%02X:%02X:%02X:%02X, Length: %u\n",
                   portid,
                   eth_hdr->src_addr.addr_bytes[0], eth_hdr->src_addr.addr_bytes[1],
                   eth_hdr->src_addr.addr_bytes[2], eth_hdr->src_addr.addr_bytes[3],
                   eth_hdr->src_addr.addr_bytes[4], eth_hdr->src_addr.addr_bytes[5],
                   eth_hdr->dst_addr.addr_bytes[0], eth_hdr->dst_addr.addr_bytes[1],
                   eth_hdr->dst_addr.addr_bytes[2], eth_hdr->dst_addr.addr_bytes[3],
                   eth_hdr->dst_addr.addr_bytes[4], eth_hdr->dst_addr.addr_bytes[5],
                   rte_pktmbuf_pkt_len(m));


            // IMPORTANT: Release the mbuf back to the pool
            rte_pktmbuf_free(m);
        }
    }

    // The loop is infinite, but in a real application you would have a signal
    // handler to gracefully shut down the port and clean up resources.
    rte_eth_dev_stop(portid);
    rte_eth_dev_close(portid);

    return 0;
}

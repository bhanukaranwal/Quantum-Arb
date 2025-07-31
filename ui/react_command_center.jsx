import React, { useState, useEffect } from 'react';

// --- Mock API Endpoints ---
const API_ENDPOINTS = {
    portfolio: '/api/portfolio',
    var: '/api/var',
    alerts: '/api/alerts',
    dynamicRisk: '/api/dynamic-risk',
    graphOpp: '/api/graph-opportunities'
};

// --- Helper Functions ---
const formatCurrency = (value) => {
    if (typeof value !== 'number') return '$0.00';
    return value.toLocaleString('en-US', {
        style: 'currency',
        currency: 'USD',
    });
};

// --- Mock API Fetcher ---
const getMockResponse = (url) => {
    return new Promise(resolve => setTimeout(() => {
        let data;
        if (url === API_ENDPOINTS.portfolio) {
            data = {
                positions: {
                    "BTC": { symbol: "BTC", quantity: 2, average_entry_price: 60100.50, unrealized_pnl: 15.70 + (Math.random() * 5) },
                    "ETH": { symbol: "ETH", quantity: -10, average_entry_price: 3005.00, unrealized_pnl: -45.20 + (Math.random() * 10) }
                },
                realized_pnl: 1250.45,
                total_unrealized_pnl: -29.50 + (Math.random() * 15)
            };
        } else if (url === API_ENDPOINTS.var) {
            data = { var_amount: 18450.75 + (Math.random() * 1000 - 500) };
        } else if (url === API_ENDPOINTS.alerts) {
            data = Math.random() > 0.3 ? [{ alert_id: "ALERT-12345", strategy_id: "NLP-NEWS-TRADER", pattern_detected: "Potential Layering/Spoofing", description: "Large order canceled within 200ms of fill." }] : [];
        } else if (url === API_ENDPOINTS.dynamicRisk) {
            data = { current_max_order_size: Math.random() > 0.2 ? 100 : 75 };
        } else if (url === API_ENDPOINTS.graphOpp) {
            data = Math.random() > 0.5 ? [{ path: ["USD", "EUR", "JPY", "USD"], profit_ratio: 1.015 }] : [];
        }
        resolve(data);
    }, 500 + Math.random() * 500));
};

// --- SVG Icons ---
const Icons = {
    Health: () => <svg xmlns="http://www.w3.org/2000/svg" className="h-6 w-6 mr-2" fill="none" viewBox="0 0 24 24" stroke="currentColor"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M13 10V3L4 14h7v7l9-11h-7z" /></svg>,
    Portfolio: () => <svg xmlns="http://www.w3.org/2000/svg" className="h-6 w-6 mr-2" fill="none" viewBox="0 0 24 24" stroke="currentColor"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M17 20h5v-2a3 3 0 00-5.356-1.857M17 20H7m10 0v-2c0-.656-.126-1.283-.356-1.857M7 20H2v-2a3 3 0 015.356-1.857M7 20v-2c0-.656.126-1.283.356-1.857m0 0a5.002 5.002 0 019.288 0M15 7a3 3 0 11-6 0 3 3 0 016 0zm6 3a2 2 0 11-4 0 2 2 0 014 0zM7 10a2 2 0 11-4 0 2 2 0 014 0z" /></svg>,
    Strategy: () => <svg xmlns="http://www.w3.org/2000/svg" className="h-6 w-6 mr-2" fill="none" viewBox="0 0 24 24" stroke="currentColor"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M9 3v2m6-2v2M9 19v2m6-2v2M5 9H3m2 6H3m18-6h-2m2 6h-2M12 6V3m0 18v-3M7 7l2 2m8 8l2 2M7 17l2-2m8-8l2-2" /></svg>,
    Compliance: () => <svg xmlns="http://www.w3.org/2000/svg" className="h-6 w-6 mr-2" fill="none" viewBox="0 0 24 24" stroke="currentColor"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M9 12l2 2 4-4m5.618-4.016A11.955 11.955 0 0112 2.944a11.955 11.955 0 01-8.618 3.04A12.02 12.02 0 003 9c0 5.591 3.824 10.29 9 11.622 5.176-1.332 9-6.03 9-11.622 0-1.042-.133-2.052-.382-3.016z" /></svg>,
    Graph: () => <svg xmlns="http://www.w3.org/2000/svg" className="h-6 w-6 mr-2" fill="none" viewBox="0 0 24 24" stroke="currentColor"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M11 4a2 2 0 114 0v1a1 1 0 001 1h3a1 1 0 011 1v3a1 1 0 01-1 1h-1a2 2 0 100 4h1a1 1 0 011 1v3a1 1 0 01-1 1h-3a1 1 0 01-1-1v-1a2 2 0 10-4 0v1a1 1 0 01-1 1H7a1 1 0 01-1-1v-3a1 1 0 00-1-1H4a2 2 0 110-4h1a1 1 0 001-1V7a1 1 0 011-1h3a1 1 0 001-1V4z" /></svg>,
};

// --- Reusable Components ---

const Card = ({ children, className = '' }) => (
    <div className={`card bg-gray-900/70 rounded-lg p-6 border border-gray-700/50 ${className}`}>
        {children}
    </div>
);

const MetricCard = ({ title, value, colorClass }) => (
    <Card className="text-center">
        <h3 className="text-sm font-medium text-gray-400">{title}</h3>
        <p className={`text-3xl font-bold my-2 ${colorClass}`}>{value}</p>
    </Card>
);

const SectionHeader = ({ title, icon }) => (
    <h2 className="text-2xl font-semibold border-b-2 border-gray-700 pb-2 mb-4 flex items-center text-gray-200">
        {icon} {title}
    </h2>
);

// --- Main App Components ---

const Header = () => {
    const [time, setTime] = useState(new Date());

    useEffect(() => {
        const timer = setInterval(() => setTime(new Date()), 1000);
        return () => clearInterval(timer);
    }, []);

    return (
        <header className="flex justify-between items-center mb-8">
            <div>
                <h1 className="text-4xl font-bold text-white">QuantumArb 2.0 Command Center</h1>
                <p className="text-gray-400">Real-time strategy, risk, portfolio, and compliance management.</p>
            </div>
            <div className="text-right">
                <p className="text-2xl font-mono text-gray-300">{time.toLocaleTimeString()}</p>
                <p className="text-xs text-gray-500">Last Updated: <span id="last-updated">{time.toLocaleTimeString()}</span></p>
            </div>
        </header>
    );
};

const SystemHealth = () => {
    const [statuses, setStatuses] = useState({
        cme: true, nasdaq: true, dataFeed: true,
        strategyEngine: true, riskGateway: true, portfolioManager: true
    });

    useEffect(() => {
        const interval = setInterval(() => {
            setStatuses(prev => ({ ...prev, portfolioManager: Math.random() > 0.1 }));
        }, 5000);
        return () => clearInterval(interval);
    }, []);

    const StatusIndicator = ({ label, isConnected }) => {
        const color = isConnected ? 'green' : 'red';
        return (
            <div className="bg-gray-800/50 rounded-lg p-3 flex items-center justify-center space-x-2 border border-gray-700/50">
                <span className={`w-3 h-3 bg-${color}-500 rounded-full animate-pulse`}></span>
                <span className="text-gray-300">{label}</span>
                <span className={`font-bold text-${color}-400`}>{isConnected ? 'Online' : 'Offline'}</span>
            </div>
        );
    };

    return (
        <section className="mb-10">
            <SectionHeader title="System Health & Connectivity" icon={<Icons.Health />} />
            <div className="grid grid-cols-2 md:grid-cols-4 lg:grid-cols-6 gap-4 text-sm">
                <StatusIndicator label="CME" isConnected={statuses.cme} />
                <StatusIndicator label="Nasdaq" isConnected={statuses.nasdaq} />
                <StatusIndicator label="Data Feed" isConnected={statuses.dataFeed} />
                <StatusIndicator label="Strategy Engine" isConnected={statuses.strategyEngine} />
                <StatusIndicator label="Risk Gateway" isConnected={statuses.riskGateway} />
                <StatusIndicator label="Portfolio Mgr" isConnected={statuses.portfolioManager} />
            </div>
        </section>
    );
};

const Portfolio = () => {
    const [portfolio, setPortfolio] = useState({ positions: {}, total_unrealized_pnl: 0, realized_pnl: 0 });

    useEffect(() => {
        const fetchData = async () => setPortfolio(await getMockResponse(API_ENDPOINTS.portfolio));
        fetchData();
        const interval = setInterval(fetchData, 2000);
        return () => clearInterval(interval);
    }, []);

    return (
        <div>
            <SectionHeader title="Live Portfolio" icon={<Icons.Portfolio />} />
            <Card>
                <table className="w-full text-left">
                    <thead>
                        <tr className="border-b border-gray-700">
                            <th className="p-2 text-gray-400">Symbol</th>
                            <th className="p-2 text-gray-400">Quantity</th>
                            <th className="p-2 text-gray-400">Avg. Entry</th>
                            <th className="p-2 text-gray-400">Unrealized P&L</th>
                        </tr>
                    </thead>
                    <tbody>
                        {Object.values(portfolio.positions).map(pos => (
                            <tr key={pos.symbol} className="border-b border-gray-800 last:border-b-0">
                                <td className="p-2 font-mono text-white">{pos.symbol}</td>
                                <td className="p-2 font-mono text-white">{pos.quantity}</td>
                                <td className="p-2 font-mono text-white">{formatCurrency(pos.average_entry_price)}</td>
                                <td className={`p-2 font-mono ${pos.unrealized_pnl >= 0 ? 'text-green-400' : 'text-red-400'}`}>
                                    {formatCurrency(pos.unrealized_pnl)}
                                </td>
                            </tr>
                        ))}
                    </tbody>
                </table>
            </Card>
        </div>
    );
};

const StrategyControl = () => {
    const [strategies, setStrategies] = useState([
        { id: 'BTC-USD-LSE-CME', name: 'BTC/USD Arbitrage', status: 'active', trade_count: 152, pnl: 450.75 },
        { id: 'ETH-FX-SATELLITE', name: 'ETH FX Satellite Algo', status: 'active', trade_count: 88, pnl: -120.50 },
        { id: 'NLP-NEWS-TRADER', name: 'NLP News Trader (S&P)', status: 'inactive', trade_count: 0, pnl: 0 },
    ]);

    const toggleStrategy = (id) => {
        setStrategies(strategies.map(s =>
            s.id === id ? { ...s, status: s.status === 'active' ? 'inactive' : 'active' } : s
        ));
    };

    return (
        <div>
            <SectionHeader title="Strategy Control" icon={<Icons.Strategy />} />
            <div className="space-y-4">
                {strategies.map(s => (
                    <Card key={s.id} className={`border-l-4 ${s.status === 'active' ? 'border-green-500' : 'border-red-500'}`}>
                        <div className="flex justify-between items-start">
                            <h3 className="text-lg font-semibold text-white">{s.name}</h3>
                            <label className="relative inline-flex items-center cursor-pointer">
                                <input type="checkbox" className="sr-only peer" checked={s.status === 'active'} onChange={() => toggleStrategy(s.id)} />
                                <div className="w-11 h-6 bg-gray-600 rounded-full peer peer-checked:after:translate-x-full after:content-[''] after:absolute after:top-0.5 after:left-[2px] after:bg-white after:border after:rounded-full after:h-5 after:w-5 after:transition-all peer-checked:bg-green-500"></div>
                            </label>
                        </div>
                        <div className="flex justify-between text-sm mt-3 text-gray-400">
                            <span>Trades: <span className="font-mono text-white">{s.trade_count}</span></span>
                            <span>P&L: <span className={`font-mono ${s.pnl >= 0 ? 'text-green-400' : 'text-red-400'}`}>{formatCurrency(s.pnl)}</span></span>
                        </div>
                    </Card>
                ))}
            </div>
        </div>
    );
};

const ComplianceAlerts = () => {
    const [alerts, setAlerts] = useState([]);

    useEffect(() => {
        const fetchData = async () => setAlerts(await getMockResponse(API_ENDPOINTS.alerts));
        fetchData();
        const interval = setInterval(fetchData, 10000);
        return () => clearInterval(interval);
    }, []);

    return (
        <div>
            <SectionHeader title="Compliance Alerts" icon={<Icons.Compliance />} />
            <div className="space-y-3">
                {alerts.length === 0 ? (
                    <Card className="text-center text-gray-400">No compliance alerts.</Card>
                ) : (
                    alerts.map(alert => (
                        <Card key={alert.alert_id} className="bg-yellow-900/50 border-l-4 border-yellow-500">
                            <p className="font-bold text-yellow-400">{alert.pattern_detected}</p>
                            <p className="text-sm text-gray-300 mt-1"><b>Strategy:</b> {alert.strategy_id}</p>
                        </Card>
                    ))
                )}
            </div>
        </div>
    );
};

const GraphOpportunities = () => {
    const [opps, setOpps] = useState([]);

    useEffect(() => {
        const fetchData = async () => setOpps(await getMockResponse(API_ENDPOINTS.graphOpp));
        fetchData();
        const interval = setInterval(fetchData, 30000);
        return () => clearInterval(interval);
    }, []);

    return (
        <div>
            <SectionHeader title="Graph Engine Opportunities" icon={<Icons.Graph />} />
            <div className="space-y-3">
                {opps.length === 0 ? (
                    <Card className="text-center text-gray-400">Searching for complex arbitrage...</Card>
                ) : (
                    opps.map((opp, index) => (
                        <Card key={index} className="bg-cyan-900/50 border-l-4 border-cyan-500">
                            <p className="font-bold text-cyan-400">Triangular Arbitrage Detected</p>
                            <p className="text-sm text-gray-300 mt-1"><b>Path:</b> {opp.path.join(' -> ')}</p>
                        </Card>
                    ))
                )}
            </div>
        </div>
    );
};

// --- Main App Component ---

export default function App() {
    const [metrics, setMetrics] = useState({ var: 0, unrealizedPnl: 0, realizedPnl: 0, dynamicLimit: 0 });

    useEffect(() => {
        const fetchAllMetrics = async () => {
            const [portfolioData, varData, dynamicRiskData] = await Promise.all([
                getMockResponse(API_ENDPOINTS.portfolio),
                getMockResponse(API_ENDPOINTS.var),
                getMockResponse(API_ENDPOINTS.dynamicRisk),
            ]);
            setMetrics({
                var: varData.var_amount,
                unrealizedPnl: portfolioData.total_unrealized_pnl,
                realizedPnl: portfolioData.realized_pnl,
                dynamicLimit: dynamicRiskData.current_max_order_size,
            });
        };
        fetchAllMetrics();
        const interval = setInterval(fetchAllMetrics, 2000);
        return () => clearInterval(interval);
    }, []);

    return (
        <div className="bg-black min-h-screen text-white">
            <div className="container mx-auto p-4 md:p-8">
                <Header />
                <SystemHealth />

                <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6 mb-10">
                    <MetricCard title="Portfolio VaR (99%)" value={formatCurrency(metrics.var)} colorClass="text-red-400" />
                    <MetricCard title="Unrealized P&L" value={formatCurrency(metrics.unrealizedPnl)} colorClass={metrics.unrealizedPnl >= 0 ? "text-cyan-400" : "text-red-400"} />
                    <MetricCard title="Realized P&L (Today)" value={formatCurrency(metrics.realizedPnl)} colorClass="text-green-400" />
                    <MetricCard title="Dynamic Max Order Size" value={metrics.dynamicLimit} colorClass="text-orange-400" />
                </div>

                <div className="grid grid-cols-1 lg:grid-cols-3 gap-8">
                    <div className="lg:col-span-2 space-y-10">
                        <Portfolio />
                        <GraphOpportunities />
                    </div>
                    <div className="lg:col-span-1 space-y-10">
                        <StrategyControl />
                        <ComplianceAlerts />
                    </div>
                </div>
            </div>
        </div>
    );
}

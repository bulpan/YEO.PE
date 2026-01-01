import { useState, useEffect, useRef } from 'react';

export default function PushLogs() {
    const [logs, setLogs] = useState([]);
    const [autoScroll, setAutoScroll] = useState(true);
    const logsEndRef = useRef(null);

    const fetchLogs = async () => {
        try {
            const token = localStorage.getItem('adminToken');
            // Filter logs by '[PushSummary]' tag for concise view
            const res = await fetch('/api/admin/logs?filter=PushSummary', {
                headers: { Authorization: `Bearer ${token}` }
            });
            const data = await res.json();
            if (data.logs) {
                setLogs(data.logs);
            }
        } catch (err) {
            console.error('Failed to fetch logs', err);
        }
    };

    useEffect(() => {
        fetchLogs();
        const interval = setInterval(fetchLogs, 2000); // Poll every 2s
        return () => clearInterval(interval);
    }, []);

    useEffect(() => {
        if (autoScroll && logsEndRef.current) {
            logsEndRef.current.scrollIntoView({ behavior: 'smooth' });
        }
    }, [logs, autoScroll]);

    return (
        <div className="space-y-4 h-[calc(100vh-140px)] flex flex-col">
            <div className="flex justify-between items-center">
                <h2 className="text-xl font-bold text-green-400">Push Notification Logs</h2>
                <div className="flex gap-2">
                    <button
                        onClick={fetchLogs}
                        className="px-3 py-1 bg-gray-700 hover:bg-gray-600 rounded text-sm"
                    >
                        Refresh Now
                    </button>
                    <label className="flex items-center space-x-2 text-sm text-gray-400 cursor-pointer">
                        <input
                            type="checkbox"
                            checked={autoScroll}
                            onChange={(e) => setAutoScroll(e.target.checked)}
                            className="rounded bg-gray-700 border-gray-600"
                        />
                        <span>Auto Scroll</span>
                    </label>
                </div>
            </div>

            <div className="flex-1 bg-black rounded-lg border border-gray-700 p-4 overflow-auto font-mono text-xs">
                {logs.length === 0 ? (
                    <div className="text-gray-500 text-center mt-10">No Push logs found...</div>
                ) : (
                    logs.map((log, i) => {
                        const isObject = typeof log === 'object' && log !== null;
                        const timestamp = isObject ? (log.timestamp || '') : '';
                        const level = isObject ? (log.level || '').toUpperCase() : '';
                        const message = isObject ? (log.message || JSON.stringify(log)) : log;

                        return (
                            <div key={i} className="border-b border-gray-900 py-1 hover:bg-gray-900 font-mono text-xs">
                                <span className="text-gray-500 mr-2 w-6 inline-block text-right">{i + 1}</span>
                                <span className="text-gray-400 mr-2">[{timestamp}]</span>
                                <span className={`mr-2 font-bold ${level === 'ERROR' ? 'text-red-500' : 'text-blue-400'}`}>
                                    [{level}]
                                </span>
                                <span className="text-gray-300 whitespace-pre-wrap">{message}</span>
                            </div>
                        );
                    })
                )}
                <div ref={logsEndRef} />
            </div>
        </div>
    );
}

import { useEffect, useState } from 'react';
import api from '../utils/api';

export default function Logs() {
    const [logs, setLogs] = useState([]);
    const [loading, setLoading] = useState(true);

    useEffect(() => {
        fetchLogs();
    }, []);

    const fetchLogs = async () => {
        try {
            const res = await api.get('/logs');
            setLogs(res.data.logs || []);
            setLoading(false);
        } catch (error) {
            console.error(error);
            setLoading(false);
        }
    };

    return (
        <div className="space-y-6 h-[calc(100vh-140px)] flex flex-col">
            <div className="flex items-center justify-between">
                <h2 className="text-2xl font-bold text-white">서버 콘솔</h2>
                <button
                    onClick={fetchLogs}
                    className="px-4 py-2 bg-blue-600 hover:bg-blue-700 text-white rounded-lg transition-colors"
                >
                    새로고침
                </button>
            </div>

            <div className="flex-1 bg-gray-950 rounded-xl overflow-hidden border border-gray-800 shadow-lg p-4">
                <div className="h-full overflow-auto font-mono text-sm">
                    {loading ? (
                        <p className="text-gray-500">Loading logs...</p>
                    ) : logs.length === 0 ? (
                        <p className="text-gray-500">로그가 없습니다.</p>
                    ) : (
                        logs.map((line, index) => (
                            <div key={index} className="text-gray-300 hover:bg-gray-900 border-b border-gray-900 py-0.5 px-2 break-all">
                                {line}
                            </div>
                        ))
                    )}
                </div>
            </div>
        </div>
    );
}

import { useEffect, useState } from 'react';
import api from '../utils/api';

export default function Dashboard() {
    const [stats, setStats] = useState(null);
    const [loading, setLoading] = useState(true);

    useEffect(() => {
        fetchStats();
        const interval = setInterval(fetchStats, 5000); // 5초마다 갱신
        return () => clearInterval(interval);
    }, []);

    const fetchStats = async () => {
        try {
            const res = await api.get('/stats');
            setStats(res.data);
            setLoading(false);
        } catch (error) {
            console.error('Failed to fetch stats:', error);
            setLoading(false);
        }
    };

    if (loading) return <div className="text-center mt-20">Loading...</div>;
    if (!stats) return <div className="text-center mt-20 text-red-500">데이터를 불러오지 못했습니다.</div>;

    return (
        <div className="space-y-6">
            {/* Stats Grid */}
            <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6">
                <StatCard
                    title="현재 접속자"
                    value={stats.activeUsers}
                    color="bg-blue-500"
                />
                <StatCard
                    title="활성 채팅방"
                    value={stats.totalRooms}
                    color="bg-green-500"
                />
                <StatCard
                    title="일일 메시지"
                    value={stats.messages24h}
                    color="bg-purple-500"
                />
                <StatCard
                    title="총 사용자"
                    value={stats.totalUsers}
                    color="bg-orange-500"
                />
            </div>

            {/* TODO: Add Charts or Logs here */}
            <div className="bg-gray-800 rounded-xl p-6 border border-gray-700">
                <h3 className="text-lg font-semibold mb-4 text-white">시스템 상태</h3>
                <p className="text-gray-400">실시간 데이터가 5초마다 갱신됩니다.</p>
            </div>
        </div>
    );
}

function StatCard({ title, value, color }) {
    return (
        <div className="bg-gray-800 rounded-xl p-6 border border-gray-700 shadow-lg hover:border-gray-600 transition-colors">
            <div className="flex items-center justify-between">
                <div>
                    <p className="text-sm font-medium text-gray-400">{title}</p>
                    <p className="text-3xl font-bold text-white mt-1">{value?.toLocaleString()}</p>
                </div>
                <div className={`w-3 h-3 rounded-full ${color} animate-pulse`}></div>
            </div>
        </div>
    );
}

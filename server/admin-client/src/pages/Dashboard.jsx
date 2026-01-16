import { useEffect, useState } from 'react';
import api from '../utils/api';
import { LineChart, Line, BarChart, Bar, XAxis, YAxis, CartesianGrid, Tooltip, Legend, ResponsiveContainer } from 'recharts';

export default function Dashboard() {
    const [stats, setStats] = useState(null);
    const [trafficData, setTrafficData] = useState([]);
    const [userData, setUserData] = useState([]);
    const [loading, setLoading] = useState(true);

    // Filters
    const [period, setPeriod] = useState('week'); // day, week, month, 3months
    const [os, setOs] = useState('all'); // all, ios, android

    useEffect(() => {
        fetchStats();
        fetchCharts();
        const interval = setInterval(fetchStats, 5000);
        return () => clearInterval(interval);
    }, []);

    useEffect(() => {
        fetchCharts();
    }, [period, os]);

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

    const fetchCharts = async () => {
        try {
            const trafficRes = await api.get(`/stats/traffic?period=${period}&os=${os}`);
            setTrafficData(trafficRes.data.data);

            const userRes = await api.get(`/stats/users?period=${period}`);
            setUserData(userRes.data.data);
        } catch (error) {
            console.error('Failed to fetch chart data:', error);
        }
    };

    if (loading) return <div className="text-center mt-20">Loading...</div>;
    if (!stats) return <div className="text-center mt-20 text-red-500">데이터를 불러오지 못했습니다.</div>;

    return (
        <div className="space-y-6">
            {/* Stats Grid */}
            <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6">
                <StatCard title="현재 접속자" value={stats.activeUsers} color="bg-blue-500" />
                <StatCard title="활성 채팅방" value={stats.totalRooms} color="bg-green-500" />
                <StatCard title="일일 메시지" value={stats.messages24h} color="bg-purple-500" />
                <StatCard title="총 사용자" value={stats.totalUsers} color="bg-orange-500" />
                <StatCard title="이용 정지" value={stats.suspendedUsers} color="bg-red-600" />
            </div>

            {/* Filters */}
            <div className="flex space-x-4 bg-gray-800 p-4 rounded-xl border border-gray-700">
                <select
                    value={period}
                    onChange={(e) => setPeriod(e.target.value)}
                    className="bg-gray-700 text-white rounded px-3 py-2 outline-none"
                >
                    <option value="day">최근 24시간</option>
                    <option value="week">최근 1주일</option>
                    <option value="month">최근 1개월</option>
                    <option value="3months">최근 3개월</option>
                </select>

                <select
                    value={os}
                    onChange={(e) => setOs(e.target.value)}
                    className="bg-gray-700 text-white rounded px-3 py-2 outline-none"
                >
                    <option value="all">모든 OS</option>
                    <option value="ios">iOS</option>
                    <option value="android">Android</option>
                </select>
            </div>

            {/* Charts */}
            <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
                {/* Traffic Chart */}
                <div className="bg-gray-800 rounded-xl p-6 border border-gray-700">
                    <h3 className="text-lg font-semibold mb-4 text-white">접속자 추이 (Active Users)</h3>
                    <div className="h-64">
                        <ResponsiveContainer width="100%" height="100%">
                            <LineChart data={trafficData}>
                                <CartesianGrid strokeDasharray="3 3" stroke="#374151" />
                                <XAxis dataKey="date" stroke="#9CA3AF" />
                                <YAxis stroke="#9CA3AF" />
                                <Tooltip contentStyle={{ backgroundColor: '#1F2937', border: 'none' }} />
                                <Legend />
                                <Line type="monotone" dataKey="count" stroke="#3B82F6" name="접속자 수" strokeWidth={2} />
                            </LineChart>
                        </ResponsiveContainer>
                    </div>
                </div>

                {/* New Users Chart */}
                <div className="bg-gray-800 rounded-xl p-6 border border-gray-700">
                    <h3 className="text-lg font-semibold mb-4 text-white">신규 가입자 (New Users)</h3>
                    <div className="h-64">
                        <ResponsiveContainer width="100%" height="100%">
                            <BarChart data={userData}>
                                <CartesianGrid strokeDasharray="3 3" stroke="#374151" />
                                <XAxis dataKey="date" stroke="#9CA3AF" />
                                <YAxis stroke="#9CA3AF" />
                                <Tooltip contentStyle={{ backgroundColor: '#1F2937', border: 'none' }} />
                                <Legend />
                                <Bar dataKey="count" fill="#10B981" name="가입자 수" />
                            </BarChart>
                        </ResponsiveContainer>
                    </div>
                </div>
            </div>

            <div className="bg-gray-800 rounded-xl p-6 border border-gray-700">
                <h3 className="text-lg font-semibold mb-4 text-white">시스템 상태</h3>
                <p className="text-gray-400">실시간 데이터가 5초마다 갱신됩니다.</p>
            </div>
        </div>
    );
}

function StatCard({ title, value, color }) {
    return (
        <div className="bg-gray-800 rounded-xl p-6 border border-gray-700 shadow-lg">
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

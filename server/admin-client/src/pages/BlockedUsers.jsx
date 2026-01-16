import { useEffect, useState } from 'react';
import api from '../utils/api';

export default function BlockedUsers() {
    const [blocks, setBlocks] = useState([]);
    const [loading, setLoading] = useState(true);

    useEffect(() => {
        fetchBlocks();
    }, []);

    const fetchBlocks = async () => {
        try {
            const res = await api.get('/blocks');
            setBlocks(res.data);
            setLoading(false);
        } catch (error) {
            console.error(error);
            setLoading(false);
        }
    };

    const handleUnblock = async (blockerId, blockedId) => {
        if (!confirm('차단을 정말 해제하시겠습니까?')) return;
        try {
            await api.post('/blocks/unblock', { blockerId, blockedId });
            alert('차단이 해제되었습니다.');
            fetchBlocks();
        } catch (error) {
            console.error(error);
            alert('해제 실패');
        }
    };

    return (
        <div className="space-y-6">
            <h2 className="text-2xl font-bold text-white">차단 사용자 관리</h2>

            <div className="bg-gray-800 rounded-xl overflow-hidden shadow-lg border border-gray-700">
                <table className="w-full text-left">
                    <thead className="bg-gray-700 text-gray-300">
                        <tr>
                            <th className="p-4">차단한 사람 (Blocker)</th>
                            <th className="p-4">차단된 사람 (Blocked)</th>
                            <th className="p-4">차단일</th>
                            <th className="p-4">관리</th>
                        </tr>
                    </thead>
                    <tbody className="divide-y divide-gray-700">
                        {blocks.length === 0 ? (
                            <tr>
                                <td colSpan="4" className="p-8 text-center text-gray-500">
                                    차단 내역이 없습니다.
                                </td>
                            </tr>
                        ) : (
                            blocks.map((item, idx) => (
                                <tr key={`${item.blocker_id}-${item.blocked_id}`} className="hover:bg-gray-700/50 transition-colors">
                                    <td className="p-4">
                                        <div className="text-white font-medium">{item.blocker_nickname || 'Unknown'}</div>
                                        <div className="text-gray-500 text-sm">{item.blocker_email}</div>
                                        <div className="text-gray-600 text-xs mt-1">{item.blocker_id}</div>
                                    </td>
                                    <td className="p-4">
                                        <div className="text-white font-medium">{item.blocked_nickname || 'Unknown'}</div>
                                        <div className="text-gray-500 text-sm">{item.blocked_email}</div>
                                        <div className="text-gray-600 text-xs mt-1">{item.blocked_id}</div>
                                    </td>
                                    <td className="p-4 text-gray-400">
                                        {new Date(item.created_at).toLocaleString()}
                                    </td>
                                    <td className="p-4">
                                        <button
                                            onClick={() => handleUnblock(item.blocker_id, item.blocked_id)}
                                            className="px-3 py-1 bg-red-500/10 text-red-400 rounded hover:bg-red-500/20 transition-colors text-sm"
                                        >
                                            차단 해제
                                        </button>
                                    </td>
                                </tr>
                            ))
                        )}
                    </tbody>
                </table>
            </div>
        </div>
    );
}

import { useEffect, useState } from 'react';
import api from '../utils/api';

export default function Appeals() {
    const [appeals, setAppeals] = useState([]);
    const [loading, setLoading] = useState(true);
    const [activeTab, setActiveTab] = useState('pending'); // pending, approved, rejected

    useEffect(() => {
        fetchAppeals();
    }, [activeTab]);

    const fetchAppeals = async () => {
        try {
            setLoading(true);
            const res = await api.get(`/appeals?status=${activeTab}`);
            setAppeals(res.data);
            setLoading(false);
        } catch (error) {
            console.error(error);
            setLoading(false);
        }
    };

    const handleResolve = async (id, status) => {
        const comment = prompt('관리자 코멘트 (선택사항):');
        if (comment === null) return; // Cancelled

        if (!window.confirm(`${status === 'approved' ? '승인' : '거절'} 처리하시겠습니까?`)) return;

        try {
            await api.post(`/appeals/${id}/resolve`, {
                status,
                adminComment: comment || ''
            });
            alert('처리되었습니다.');
            fetchAppeals();
        } catch (error) {
            console.error(error);
            alert('처리 실패');
        }
    };

    return (
        <div className="space-y-6">
            <div className="flex justify-between items-center">
                <h2 className="text-2xl font-bold text-white">구제 신청 관리 (Appeals)</h2>
                <div className="space-x-2 bg-gray-800 p-1 rounded-lg">
                    {['pending', 'approved', 'rejected'].map(tab => (
                        <button
                            key={tab}
                            onClick={() => setActiveTab(tab)}
                            className={`px-4 py-2 rounded-md transition-colors ${activeTab === tab
                                ? 'bg-blue-600 text-white shadow'
                                : 'text-gray-400 hover:text-white'}`}
                        >
                            {tab.charAt(0).toUpperCase() + tab.slice(1)}
                        </button>
                    ))}
                </div>
            </div>

            <div className="bg-gray-800 rounded-xl overflow-hidden shadow-lg border border-gray-700">
                <table className="w-full text-left">
                    <thead className="bg-gray-700 text-gray-300">
                        <tr>
                            <th className="p-4">신청자</th>
                            <th className="p-4">사유</th>
                            <th className="p-4">현재 상태</th>
                            <th className="p-4">정지 만료일</th>
                            <th className="p-4">신청일</th>
                            {activeTab !== 'pending' && <th className="p-4">처리 코멘트</th>}
                            {activeTab === 'pending' && <th className="p-4">관리</th>}
                        </tr>
                    </thead>
                    <tbody className="divide-y divide-gray-700">
                        {appeals.length === 0 ? (
                            <tr>
                                <td colSpan="7" className="p-8 text-center text-gray-500">
                                    데이터가 없습니다.
                                </td>
                            </tr>
                        ) : (
                            appeals.map((appeal) => (
                                <tr key={appeal.id} className="hover:bg-gray-700/50 transition-colors">
                                    <td className="p-4 font-medium text-white">
                                        <div>{appeal.nickname}</div>
                                        <div className="text-xs text-gray-500">{appeal.email}</div>
                                    </td>
                                    <td className="p-4 text-gray-300 max-w-xs break-words">
                                        {appeal.reason}
                                    </td>
                                    <td className="p-4">
                                        <div className="flex flex-col gap-1">
                                            <span className={`px-2 py-1 rounded text-xs w-fit bg-gray-600 text-gray-300`}>
                                                User: {appeal.user_status}
                                            </span>
                                        </div>
                                    </td>
                                    <td className="p-4 text-gray-400 text-sm">
                                        {appeal.suspended_until ? new Date(appeal.suspended_until).toLocaleString() : '-'}
                                    </td>
                                    <td className="p-4 text-gray-400 text-sm">
                                        {new Date(appeal.created_at).toLocaleDateString()}
                                    </td>
                                    {activeTab !== 'pending' && (
                                        <td className="p-4 text-gray-400 text-sm">
                                            {appeal.admin_comment || '-'}
                                        </td>
                                    )}
                                    {activeTab === 'pending' && (
                                        <td className="p-4">
                                            <div className="flex space-x-2">
                                                <button
                                                    onClick={() => handleResolve(appeal.id, 'approved')}
                                                    className="bg-green-600 hover:bg-green-500 text-white px-3 py-1 rounded text-sm"
                                                >
                                                    승인 (해제)
                                                </button>
                                                <button
                                                    onClick={() => handleResolve(appeal.id, 'rejected')}
                                                    className="bg-red-600 hover:bg-red-500 text-white px-3 py-1 rounded text-sm"
                                                >
                                                    거절
                                                </button>
                                            </div>
                                        </td>
                                    )}
                                </tr>
                            ))
                        )}
                    </tbody>
                </table>
            </div>
        </div>
    );
}

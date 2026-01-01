import { useState, useEffect } from 'react';
import api from '../utils/api';

export default function Reports() {
    const [reports, setReports] = useState([]);

    useEffect(() => {
        fetchReports();
    }, []);

    const fetchReports = async () => {
        try {
            const res = await api.get('/reports');
            setReports(res.data);
        } catch (error) {
            console.error('Failed to fetch reports', error);
        }
    };

    const handleBan = async (userId) => {
        if (!window.confirm('이 사용자를 차단하시겠습니까?')) return;
        try {
            await api.post(`/users/${userId}/ban`);
            alert('사용자가 차단되었습니다.');
            fetchReports(); // Refresh
        } catch (error) {
            alert('차단 실패');
        }
    };

    return (
        <div className="space-y-6">
            <h2 className="text-2xl font-bold text-white">신고 관리</h2>

            <div className="bg-gray-800 rounded-xl overflow-hidden border border-gray-700 shadow-lg">
                <table className="w-full text-left text-gray-300">
                    <thead className="bg-gray-700 text-gray-100 uppercase text-xs">
                        <tr>
                            <th className="px-6 py-3">신고자</th>
                            <th className="px-6 py-3">대상자</th>
                            <th className="px-6 py-3">사유</th>
                            <th className="px-6 py-3">상세내용</th>
                            <th className="px-6 py-3">시간</th>
                            <th className="px-6 py-3">작업</th>
                        </tr>
                    </thead>
                    <tbody className="divide-y divide-gray-700">
                        {reports.map((report) => (
                            <tr key={report.id} className="hover:bg-gray-750">
                                <td className="px-6 py-4">{report.reporter_nickname}</td>
                                <td className="px-6 py-4 text-red-300 font-bold">{report.reported_nickname}</td>
                                <td className="px-6 py-4">{report.reason}</td>
                                <td className="px-6 py-4 truncate max-w-xs" title={report.details}>
                                    {report.details || '-'}
                                </td>
                                <td className="px-6 py-4 text-sm text-gray-500">
                                    {new Date(report.created_at).toLocaleString()}
                                </td>
                                <td className="px-6 py-4">
                                    <button
                                        onClick={() => handleBan(report.reported_id)}
                                        className="bg-red-900 text-red-200 px-3 py-1 rounded text-xs hover:bg-red-800"
                                    >
                                        차단
                                    </button>
                                </td>
                            </tr>
                        ))}
                    </tbody>
                </table>
                {reports.length === 0 && (
                    <div className="p-8 text-center text-gray-500">신고 내역이 없습니다.</div>
                )}
            </div>
        </div>
    );
}

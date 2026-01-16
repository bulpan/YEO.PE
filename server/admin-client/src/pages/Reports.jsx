import { useState, useEffect } from 'react';
import api from '../utils/api';
import UserActionModal from '../components/UserActionModal';

export default function Reports() {
    const [reports, setReports] = useState([]);

    // Modal State
    const [modalOpen, setModalOpen] = useState(false);
    const [actionType, setActionType] = useState('suspend'); // 'suspend' | 'ban'
    const [selectedUser, setSelectedUser] = useState(null);

    const [defaultSettings, setDefaultSettings] = useState({
        duration: 24,
        suspensionReasonKo: '',
        suspensionReasonEn: '',
        banReasonKo: '',
        banReasonEn: ''
    });

    useEffect(() => {
        fetchReports();
        fetchGlobalSettings();
    }, []);

    const fetchReports = async () => {
        try {
            const res = await api.get('/reports');
            setReports(res.data);
        } catch (error) {
            console.error('Failed to fetch reports', error);
        }
    };

    const parseReason = (reasonStr) => {
        try {
            const parsed = JSON.parse(reasonStr || '{}');
            if (typeof parsed === 'object') return parsed;
            return { ko: reasonStr, en: reasonStr };
        } catch (e) {
            return { ko: reasonStr, en: reasonStr };
        }
    };

    const fetchGlobalSettings = async () => {
        try {
            const res = await api.get('/settings');
            const susp = parseReason(res.data.suspension_reason);
            const ban = parseReason(res.data.ban_reason);

            setDefaultSettings({
                duration: parseInt(res.data.suspension_duration_hours) || 24,
                suspensionReasonKo: susp.ko || '',
                suspensionReasonEn: susp.en || '',
                banReasonKo: ban.ko || '',
                banReasonEn: ban.en || ''
            });
        } catch (error) {
            console.error('Failed to fetch settings:', error);
        }
    };

    const openModal = (userId, userNickname, type) => {
        // Construct a partial user object for the modal
        setSelectedUser({ id: userId, nickname: userNickname, email: '' });
        setActionType(type);
        setModalOpen(true);
    };

    const closeModal = () => {
        setModalOpen(false);
        setSelectedUser(null);
    };

    return (
        <div className="space-y-6 relative">
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
                                <td className="px-6 py-4 flex gap-2">
                                    <button
                                        onClick={() => openModal(report.reported_id, report.reported_nickname, 'suspend')}
                                        className="bg-orange-600 text-white px-3 py-1 rounded text-xs hover:bg-orange-500 transition-colors"
                                    >
                                        정지
                                    </button>
                                    <button
                                        onClick={() => openModal(report.reported_id, report.reported_nickname, 'ban')}
                                        className="bg-red-800 text-red-100 px-3 py-1 rounded text-xs hover:bg-red-700 transition-colors"
                                    >
                                        비활성화
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

            {/* Modal */}
            {modalOpen && (
                <UserActionModal
                    user={selectedUser}
                    type={actionType}
                    onClose={closeModal}
                    onSuccess={() => {
                        fetchReports();
                        closeModal(); // Optional, modal closes itself inside onSuccess usually? No, I passed onClose.
                    }}
                    defaultSettings={defaultSettings}
                />
            )}
        </div>
    );
}

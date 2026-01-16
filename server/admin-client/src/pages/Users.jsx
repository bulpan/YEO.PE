import { useEffect, useState } from 'react';
import api from '../utils/api';
import UserActionModal from '../components/UserActionModal';

export default function Users() {
    const [users, setUsers] = useState([]);
    const [loading, setLoading] = useState(true);

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
        fetchUsers();
        fetchGlobalSettings();
    }, []);

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

    const fetchUsers = async () => {
        try {
            const res = await api.get('/users');
            setUsers(res.data);
            setLoading(false);
        } catch (error) {
            console.error(error);
            setLoading(false);
        }
    };

    const handleUnsuspend = async (userId) => {
        if (!window.confirm('해당 사용자의 정지를 해제하시겠습니까?')) return;
        try {
            await api.post(`/users/${userId}/unsuspend`);
            alert('정지가 해제되었습니다.');
            fetchUsers();
        } catch (error) {
            console.error(error);
            alert('오류가 발생했습니다.');
        }
    };

    const handleUnban = async (userId) => {
        if (!window.confirm('해당 사용자를 활성화하시겠습니까?')) return;
        try {
            await api.post(`/users/${userId}/unblock`);
            alert('계정이 활성화되었습니다.');
            fetchUsers();
        } catch (error) {
            console.error(error);
            alert('오류가 발생했습니다.');
        }
    };

    const handleClearReports = async (userId) => {
        if (!window.confirm('해당 사용자의 신고 내역을 초기화하시겠습니까? (누적 신고수 0으로 리셋)')) return;
        try {
            await api.delete(`/users/${userId}/reports`);
            alert('신고 내역이 초기화되었습니다.');
            fetchUsers();
        } catch (error) {
            console.error(error);
            alert('오류가 발생했습니다.');
        }
    };

    const openModal = (user, type) => {
        setSelectedUser(user);
        setActionType(type);
        setModalOpen(true);
    };

    const closeModal = () => {
        setModalOpen(false);
        setSelectedUser(null);
    };



    return (
        <div className="space-y-6 relative">
            <h2 className="text-2xl font-bold text-white">사용자 관리</h2>

            {/* Same Table UI (Omitted for brevity, but I must preserve it. 
               Wait, I'm replacing the whole file. I MUST include the table.) 
            */}
            <div className="bg-gray-800 rounded-xl overflow-hidden shadow-lg border border-gray-700">
                <table className="w-full text-left">
                    <thead className="bg-gray-700 text-gray-300">
                        <tr>
                            <th className="p-4">닉네임</th>
                            <th className="p-4">이메일</th>
                            <th className="p-4">상태</th>
                            <th className="p-4">가입일</th>
                            <th className="p-4">최근 접속</th>
                            <th className="p-4">관리</th>
                        </tr>
                    </thead>
                    <tbody className="divide-y divide-gray-700">
                        {users.length === 0 ? (
                            <tr>
                                <td colSpan="6" className="p-8 text-center text-gray-500">
                                    사용자가 없습니다.
                                </td>
                            </tr>
                        ) : (
                            users.map((user) => (
                                <tr key={user.id} className="hover:bg-gray-700/50 transition-colors">
                                    <td className="p-4 font-medium text-white">
                                        {user.nickname} <span className="text-gray-500 text-sm">({user.nickname_mask})</span>
                                    </td>
                                    <td className="p-4 text-gray-400">{user.email}</td>
                                    <td className="p-4">
                                        <div className="flex flex-col gap-1">
                                            <span className={`px-2 py-1 rounded text-xs w-fit ${user.is_active ? 'bg-green-500/20 text-green-400' : 'bg-red-500/20 text-red-400'}`}>
                                                {user.is_active ? 'Active' : 'Inactive'}
                                            </span>
                                            {user.status && (
                                                <span className={`px-2 py-1 rounded text-xs w-fit ${user.status === 'suspended' ? 'bg-orange-500/20 text-orange-400' : 'bg-gray-600 text-gray-300'}`}>
                                                    {user.status}
                                                </span>
                                            )}
                                        </div>
                                    </td>
                                    <td className="p-4 text-gray-400">
                                        {new Date(user.created_at).toLocaleDateString()}
                                    </td>
                                    <td className="p-4 text-gray-400">
                                        {user.last_login_at ? new Date(user.last_login_at).toLocaleString() : '-'}
                                    </td>
                                    <td className="p-4 flex flex-wrap gap-2">
                                        {/* Actions based on status */}
                                        {user.status === 'suspended' ? (
                                            <button
                                                onClick={() => handleUnsuspend(user.id)}
                                                className="bg-blue-600 hover:bg-blue-500 text-white px-3 py-1 rounded text-sm transition-colors"
                                            >
                                                정지 해제
                                            </button>
                                        ) : (
                                            <button
                                                onClick={() => openModal(user, 'suspend')}
                                                className="bg-orange-600 hover:bg-orange-500 text-white px-3 py-1 rounded text-sm transition-colors"
                                            >
                                                정지
                                            </button>
                                        )}

                                        {!user.is_active ? (
                                            <button
                                                onClick={() => handleUnban(user.id)}
                                                className="bg-green-600 hover:bg-green-500 text-white px-3 py-1 rounded text-sm transition-colors"
                                            >
                                                활성화
                                            </button>
                                        ) : (
                                            <button
                                                onClick={() => openModal(user, 'ban')}
                                                className="bg-red-800 hover:bg-red-700 text-white px-3 py-1 rounded text-sm transition-colors"
                                            >
                                                비활성화
                                            </button>
                                        )}

                                        <button
                                            onClick={() => handleClearReports(user.id)}
                                            className="bg-gray-600 hover:bg-gray-500 text-white px-3 py-1 rounded text-sm transition-colors"
                                        >
                                            신고 리셋
                                        </button>
                                    </td>
                                </tr>
                            ))
                        )}
                    </tbody>
                </table>
            </div>

            {/* Modal */}
            {modalOpen && (
                <UserActionModal
                    user={selectedUser}
                    type={actionType}
                    onClose={closeModal}
                    onSuccess={() => {
                        fetchUsers();
                        closeModal();
                    }}
                    defaultSettings={defaultSettings}
                />
            )}
        </div>
    );
}

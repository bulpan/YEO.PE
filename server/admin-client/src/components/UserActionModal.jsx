import { useState, useEffect } from 'react';
import api from '../utils/api';

export default function UserActionModal({ user, type, onClose, onSuccess, defaultSettings }) {
    const [duration, setDuration] = useState(24);
    const [reasonKo, setReasonKo] = useState('');
    const [reasonEn, setReasonEn] = useState('');
    const [loading, setLoading] = useState(false);

    useEffect(() => {
        if (type === 'suspend') {
            setDuration(defaultSettings?.duration || 24);
            setReasonKo(defaultSettings?.suspensionReasonKo || '');
            setReasonEn(defaultSettings?.suspensionReasonEn || '');
        } else {
            setReasonKo(defaultSettings?.banReasonKo || '');
            setReasonEn(defaultSettings?.banReasonEn || '');
        }
    }, [type, defaultSettings]);

    const handleSubmit = async (e) => {
        e.preventDefault();
        if (!user) return;
        setLoading(true);

        const reasonPayload = {
            ko: reasonKo,
            en: reasonEn
        };

        try {
            if (type === 'suspend') {
                await api.post(`/users/${user.id}/suspend`, { hours: duration, reason: reasonPayload });
                alert('사용자가 정지되었습니다.');
            } else {
                await api.post(`/users/${user.id}/ban`, { reason: reasonPayload });
                alert('사용자가 비활성화되었습니다.');
            }
            if (onSuccess) onSuccess();
            onClose();
        } catch (error) {
            console.error(error);
            alert('오류가 발생했습니다.');
        } finally {
            setLoading(false);
        }
    };

    if (!user) return null;

    return (
        <div className="fixed inset-0 bg-black/70 flex items-center justify-center z-50">
            <div className="bg-gray-800 border border-gray-700 rounded-xl p-6 w-full max-w-md shadow-2xl overflow-y-auto max-h-[90vh]">
                <h3 className="text-xl font-bold text-white mb-4">
                    {type === 'suspend' ? '사용자 정지 (Suspension)' : '사용자 비활성화 (Deactivate)'}
                </h3>
                <form onSubmit={handleSubmit} className="space-y-4">
                    <div>
                        <label className="block text-sm font-medium text-gray-400 mb-1">대상 사용자</label>
                        <div className="text-white font-mono">
                            {user.nickname} {user.email ? `(${user.email})` : ''}
                        </div>
                    </div>

                    {type === 'suspend' && (
                        <div>
                            <label className="block text-sm font-medium text-gray-400 mb-1">정지 기간 (시간)</label>
                            <input
                                type="number"
                                min="1"
                                value={duration}
                                onChange={(e) => setDuration(e.target.value)}
                                className="w-full bg-gray-700 border border-gray-600 rounded p-2 text-white focus:outline-none focus:border-blue-500"
                                required
                            />
                            <p className="text-xs text-gray-500 mt-1">예: 24 = 24시간, 720 = 30일</p>
                        </div>
                    )}

                    <div>
                        <label className="block text-sm font-medium text-gray-400 mb-1">
                            {type === 'suspend' ? '정지 사유 (한국어)' : '비활성화 사유 (한국어)'}
                        </label>
                        <textarea
                            value={reasonKo}
                            onChange={(e) => setReasonKo(e.target.value)}
                            placeholder="사용자에게 표시될 사유를 입력하세요..."
                            className="w-full bg-gray-700 border border-gray-600 rounded p-2 text-white focus:outline-none focus:border-blue-500 h-20"
                            required
                        />
                    </div>

                    <div>
                        <label className="block text-sm font-medium text-gray-400 mb-1">
                            {type === 'suspend' ? 'Reason (English)' : 'Reason (English)'}
                        </label>
                        <textarea
                            value={reasonEn}
                            onChange={(e) => setReasonEn(e.target.value)}
                            placeholder="Reason displayed to the user..."
                            className="w-full bg-gray-700 border border-gray-600 rounded p-2 text-white focus:outline-none focus:border-blue-500 h-20"
                            required
                        />
                    </div>

                    <div className="flex justify-end gap-3 mt-6">
                        <button
                            type="button"
                            onClick={onClose}
                            className="px-4 py-2 rounded bg-gray-600 text-white hover:bg-gray-500 transition-colors"
                        >
                            취소
                        </button>
                        <button
                            type="submit"
                            disabled={loading}
                            className={`px-4 py-2 rounded text-white transition-colors ${type === 'suspend' ? 'bg-orange-600 hover:bg-orange-500' : 'bg-red-600 hover:bg-red-500'} ${loading ? 'opacity-50 cursor-not-allowed' : ''}`}
                        >
                            {loading ? '처리 중...' : (type === 'suspend' ? '정지 적용' : '비활성화 적용')}
                        </button>
                    </div>
                </form>
            </div>
        </div>
    );
}

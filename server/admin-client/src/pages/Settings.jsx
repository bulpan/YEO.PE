import { useEffect, useState } from 'react';
import api from '../utils/api';

export default function Settings() {
    const [settings, setSettings] = useState({
        suspension_duration_hours: '',
        suspension_reason_ko: '',
        suspension_reason_en: '',
        ban_reason_ko: '',
        ban_reason_en: '',

        notice_active: false,
        notice_content_ko: '',
        notice_content_en: '',
        notice_version: '0'
    });
    const [loading, setLoading] = useState(true);

    useEffect(() => {
        fetchSettings();
    }, []);

    const fetchSettings = async () => {
        try {
            const res = await api.get('/settings');
            const data = res.data;

            // Parse Suspension Reason
            let suspKo = '';
            let suspEn = '';
            try {
                const parsed = JSON.parse(data.suspension_reason || '{}');
                if (typeof parsed === 'object') {
                    suspKo = parsed.ko || '';
                    suspEn = parsed.en || '';
                } else {
                    suspKo = data.suspension_reason || '';
                    suspEn = data.suspension_reason || '';
                }
            } catch (e) {
                suspKo = data.suspension_reason || '';
                suspEn = data.suspension_reason || '';
            }

            // Parse Ban Reason
            let banKo = '';
            let banEn = '';
            try {
                const parsed = JSON.parse(data.ban_reason || '{}');
                if (typeof parsed === 'object') {
                    banKo = parsed.ko || '';
                    banEn = parsed.en || '';
                } else {
                    banKo = data.ban_reason || '';
                    banEn = data.ban_reason || '';
                }
            } catch (e) {
                banKo = data.ban_reason || '';
                banEn = data.ban_reason || '';
            }

            setSettings({
                suspension_duration_hours: data.suspension_duration_hours || '',
                suspension_reason_ko: suspKo,
                suspension_reason_en: suspEn,
                ban_reason_ko: banKo,
                ban_reason_en: banEn,

                notice_active: data.notice_active === 'true',
                notice_content_ko: data.notice_content_ko || '',
                notice_content_en: data.notice_content_en || '',
                notice_version: data.notice_version || '0'
            });
            setLoading(false);
        } catch (error) {
            console.error(error);
            setLoading(false);
        }
    };

    const handleChange = (e) => {
        const { name, value, type, checked } = e.target;
        setSettings(prev => ({
            ...prev,
            [name]: type === 'checkbox' ? checked : value
        }));
    };

    // Increment version helper
    const incrementVersion = () => {
        setSettings(prev => ({
            ...prev,
            notice_version: (parseInt(prev.notice_version || '0') + 1).toString()
        }));
    };

    const handleSubmit = async (e) => {
        e.preventDefault();
        try {
            const payload = {
                suspension_duration_hours: settings.suspension_duration_hours,
                suspension_reason: JSON.stringify({
                    ko: settings.suspension_reason_ko,
                    en: settings.suspension_reason_en
                }),
                ban_reason: JSON.stringify({
                    ko: settings.ban_reason_ko,
                    en: settings.ban_reason_en
                }),
                notice_active: settings.notice_active.toString(),
                notice_content_ko: settings.notice_content_ko,
                notice_content_en: settings.notice_content_en,
                notice_version: settings.notice_version
            };

            await api.post('/settings', payload);
            alert('설정이 저장되었습니다.');
        } catch (error) {
            console.error(error);
            alert('오류가 발생했습니다.');
        }
    };

    if (loading) return <div className="text-white">Loading...</div>;

    return (
        <div className="space-y-6 max-w-4xl">
            <h2 className="text-2xl font-bold text-white">시스템 정책 설정</h2>

            <div className="grid grid-cols-1 gap-6">
                {/* 1. App Notice Section */}
                <div className="bg-gray-800 rounded-xl p-6 shadow-lg border border-gray-700">
                    <div className="flex justify-between items-center mb-4">
                        <h3 className="text-lg font-semibold text-white">앱 메인 공지 팝업</h3>
                        <div className="flex items-center space-x-2">
                            <label className="flex items-center space-x-2 cursor-pointer">
                                <input
                                    type="checkbox"
                                    name="notice_active"
                                    checked={settings.notice_active}
                                    onChange={handleChange}
                                    className="form-checkbox h-5 w-5 text-blue-600 rounded bg-gray-700 border-gray-600"
                                />
                                <span className="text-white text-sm">활성화</span>
                            </label>
                        </div>
                    </div>

                    <div className="space-y-4">
                        {/* Version Control */}
                        <div className="flex items-center space-x-4">
                            <div className="text-gray-400 text-sm">
                                현재 버전: <span className="text-white font-mono">{settings.notice_version}</span>
                            </div>
                            <button
                                type="button"
                                onClick={incrementVersion}
                                className="bg-gray-700 hover:bg-gray-600 text-xs px-2 py-1 rounded text-white border border-gray-600"
                            >
                                버전 +1 (팝업 재노출)
                            </button>
                        </div>

                        <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                            <div>
                                <label className="block text-xs font-medium text-gray-400 mb-1">공지 내용 (한국어)</label>
                                <textarea
                                    name="notice_content_ko"
                                    value={settings.notice_content_ko}
                                    onChange={handleChange}
                                    className="w-full bg-gray-700 border border-gray-600 rounded p-2 text-white focus:outline-none focus:border-blue-500 h-24 text-sm"
                                    placeholder="한국어 공지 내용을 입력하세요"
                                />
                            </div>
                            <div>
                                <label className="block text-xs font-medium text-gray-400 mb-1">Notice Content (English)</label>
                                <textarea
                                    name="notice_content_en"
                                    value={settings.notice_content_en}
                                    onChange={handleChange}
                                    className="w-full bg-gray-700 border border-gray-600 rounded p-2 text-white focus:outline-none focus:border-blue-500 h-24 text-sm"
                                    placeholder="Enter notice content in English"
                                />
                            </div>
                        </div>
                    </div>
                </div>

                {/* 2. Suspension & Ban Section */}
                <div className="bg-gray-800 rounded-xl p-6 shadow-lg border border-gray-700">
                    <form onSubmit={handleSubmit} className="space-y-6">

                        {/* Suspension */}
                        <div className="border-b border-gray-700 pb-6">
                            <h3 className="text-lg font-semibold text-white mb-2">자동/기본 정지 (Suspension)</h3>
                            <p className="text-sm text-gray-400 mb-4">신고 누적 시 자동 적용되거나, 관리자 수동 정지 시 기본값으로 사용됩니다.</p>

                            <div className="space-y-4">
                                <div>
                                    <label className="block text-sm font-medium text-gray-400 mb-1">기본 정지 기간 (시간)</label>
                                    <input
                                        type="number"
                                        name="suspension_duration_hours"
                                        value={settings.suspension_duration_hours}
                                        onChange={handleChange}
                                        className="w-full bg-gray-700 border border-gray-600 rounded p-2 text-white focus:outline-none focus:border-blue-500"
                                        required
                                    />
                                </div>

                                <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                                    <div>
                                        <label className="block text-xs font-medium text-gray-400 mb-1">기본 정지 사유 (한국어)</label>
                                        <textarea
                                            name="suspension_reason_ko"
                                            value={settings.suspension_reason_ko}
                                            onChange={handleChange}
                                            className="w-full bg-gray-700 border border-gray-600 rounded p-2 text-white focus:outline-none focus:border-blue-500 h-24 text-sm"
                                            required
                                        />
                                    </div>
                                    <div>
                                        <label className="block text-xs font-medium text-gray-400 mb-1">Default Suspension Reason (English)</label>
                                        <textarea
                                            name="suspension_reason_en"
                                            value={settings.suspension_reason_en}
                                            onChange={handleChange}
                                            className="w-full bg-gray-700 border border-gray-600 rounded p-2 text-white focus:outline-none focus:border-blue-500 h-24 text-sm"
                                            required
                                        />
                                    </div>
                                </div>
                            </div>
                        </div>

                        {/* Deactivation */}
                        <div>
                            <h3 className="text-lg font-semibold text-white mb-2">계정 비활성화 (Deactivation)</h3>
                            <p className="text-sm text-gray-400 mb-4">관리자 수동 비활성화 시 기본값으로 사용됩니다.</p>

                            <div className="space-y-4">
                                <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                                    <div>
                                        <label className="block text-xs font-medium text-gray-400 mb-1">기본 비활성화 사유 (한국어)</label>
                                        <textarea
                                            name="ban_reason_ko"
                                            value={settings.ban_reason_ko}
                                            onChange={handleChange}
                                            className="w-full bg-gray-700 border border-gray-600 rounded p-2 text-white focus:outline-none focus:border-blue-500 h-24 text-sm"
                                            required
                                        />
                                    </div>
                                    <div>
                                        <label className="block text-xs font-medium text-gray-400 mb-1">Default Deactivation Reason (English)</label>
                                        <textarea
                                            name="ban_reason_en"
                                            value={settings.ban_reason_en}
                                            onChange={handleChange}
                                            className="w-full bg-gray-700 border border-gray-600 rounded p-2 text-white focus:outline-none focus:border-blue-500 h-24 text-sm"
                                            required
                                        />
                                    </div>
                                </div>
                            </div>
                        </div>

                        <div className="pt-4">
                            <button
                                type="submit"
                                className="bg-blue-600 hover:bg-blue-500 text-white px-6 py-2 rounded transition-colors w-full md:w-auto"
                            >
                                저장하기 (Save)
                            </button>
                        </div>
                    </form>
                </div>
            </div>
        </div>
    );
}

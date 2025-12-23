import { useEffect, useState } from 'react';
import { useParams, useNavigate } from 'react-router-dom';
import api from '../utils/api';

export default function RoomDetail() {
    const { id } = useParams();
    const navigate = useNavigate();
    const [data, setData] = useState(null);
    const [loading, setLoading] = useState(true);

    useEffect(() => {
        fetchRoomDetail();
    }, [id]);

    const fetchRoomDetail = async () => {
        try {
            const res = await api.get(`/rooms/${id}`);
            setData(res.data);
            setLoading(false);
        } catch (error) {
            console.error(error);
            alert('방을 찾을 수 없습니다.');
            navigate('/rooms');
        }
    };

    const deleteRoom = async () => {
        if (!window.confirm('정말 이 방을 삭제하시겠습니까?')) return;
        try {
            await api.delete(`/rooms/${id}`);
            navigate('/rooms');
        } catch (error) {
            alert('방 삭제 실패');
        }
    };

    if (loading || !data) return <div className="text-white">Loading...</div>;

    const { room, messages } = data;

    return (
        <div className="space-y-6">
            <div className="flex items-center justify-between">
                <h2 className="text-2xl font-bold text-white">방 상세 정보</h2>
                <div className="space-x-2">
                    <button
                        onClick={() => navigate('/rooms')}
                        className="px-4 py-2 bg-gray-600 hover:bg-gray-700 text-white rounded-lg transition-colors"
                    >
                        목록으로
                    </button>
                    <button
                        onClick={deleteRoom}
                        className="px-4 py-2 bg-red-600 hover:bg-red-700 text-white rounded-lg transition-colors"
                    >
                        방 삭제
                    </button>
                </div>
            </div>

            {/* Room Info */}
            <div className="bg-gray-800 rounded-xl p-6 border border-gray-700 shadow-lg">
                <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
                    <div>
                        <p className="text-sm text-gray-400">방 이름</p>
                        <p className="text-lg font-semibold text-white">{room.name}</p>
                    </div>
                    <div>
                        <p className="text-sm text-gray-400">개설자</p>
                        <p className="text-lg font-semibold text-white">{room.creator_nickname}</p>
                    </div>
                    <div>
                        <p className="text-sm text-gray-400">참여 인원</p>
                        <p className="text-lg font-semibold text-white">{room.member_count}명</p>
                    </div>
                    <div>
                        <p className="text-sm text-gray-400">만료 시간</p>
                        <p className="text-lg font-semibold text-white">
                            {new Date(room.expires_at).toLocaleString()}
                        </p>
                    </div>
                </div>
            </div>

            {/* Messages */}
            <div className="bg-gray-800 rounded-xl overflow-hidden border border-gray-700 shadow-lg">
                <div className="p-4 bg-gray-700 border-b border-gray-600">
                    <h3 className="text-lg font-bold text-white">최근 대화 기록</h3>
                </div>
                <div className="p-4 max-h-[500px] overflow-y-auto space-y-4">
                    {messages.length === 0 ? (
                        <p className="text-center text-gray-500">대화 내용이 없습니다.</p>
                    ) : (
                        messages.map((msg) => (
                            <div key={msg.id} className="flex flex-col space-y-1">
                                <div className="flex items-baseline space-x-2">
                                    <span className="text-sm font-bold text-blue-400">{msg.nickname}</span>
                                    <span className="text-xs text-gray-500">
                                        {new Date(msg.created_at).toLocaleTimeString()}
                                    </span>
                                </div>
                                <div className="bg-gray-700/50 p-3 rounded-lg text-gray-200">
                                    {msg.type === 'text' && msg.content}
                                    {msg.type === 'image' && (
                                        <img src={msg.image_url} alt="Uploaded" className="max-w-xs rounded" />
                                    )}
                                    {msg.type === 'emoji' && <span className="text-2xl">{msg.content}</span>}
                                </div>
                            </div>
                        ))
                    )}
                </div>
            </div>
        </div>
    );
}

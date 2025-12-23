import { useEffect, useState } from 'react';
import { Link } from 'react-router-dom';
import api from '../utils/api';

export default function Rooms() {
    const [rooms, setRooms] = useState([]);
    const [loading, setLoading] = useState(true);

    useEffect(() => {
        fetchRooms();
    }, []);

    const fetchRooms = async () => {
        try {
            const res = await api.get('/rooms');
            setRooms(res.data);
            setLoading(false);
        } catch (error) {
            console.error(error);
            setLoading(false);
        }
    };

    const deleteRoom = async (id) => {
        if (!window.confirm('정말 이 방을 삭제하시겠습니까?')) return;
        try {
            await api.delete(`/rooms/${id}`);
            fetchRooms();
        } catch (error) {
            alert('방 삭제 실패');
        }
    };

    if (loading) return <div className="text-white">Loading...</div>;

    return (
        <div className="space-y-6">
            <h2 className="text-2xl font-bold text-white">채팅방 관리</h2>

            <div className="bg-gray-800 rounded-xl overflow-hidden shadow-lg border border-gray-700">
                <table className="w-full text-left">
                    <thead className="bg-gray-700 text-gray-300">
                        <tr>
                            <th className="p-4">방 이름</th>
                            <th className="p-4">개설자</th>
                            <th className="p-4">참여 인원</th>
                            <th className="p-4">생성 시간</th>
                            <th className="p-4">관리</th>
                        </tr>
                    </thead>
                    <tbody className="divide-y divide-gray-700">
                        {rooms.length === 0 ? (
                            <tr>
                                <td colSpan="5" className="p-8 text-center text-gray-500">
                                    활성 방이 없습니다.
                                </td>
                            </tr>
                        ) : (
                            rooms.map((room) => (
                                <tr key={room.id} className="hover:bg-gray-700/50 transition-colors">
                                    <td className="p-4 font-medium text-white">{room.name}</td>
                                    <td className="p-4 text-gray-400">{room.creator_nickname}</td>
                                    <td className="p-4 text-gray-300">{room.member_count}명</td>
                                    <td className="p-4 text-gray-400">
                                        {new Date(room.created_at).toLocaleString()}
                                    </td>
                                    <td className="p-4 space-x-2">
                                        <Link
                                            to={`/rooms/${room.id}`}
                                            className="px-3 py-1 text-sm bg-blue-600 hover:bg-blue-700 text-white rounded transition-colors"
                                        >
                                            상세
                                        </Link>
                                        <button
                                            onClick={() => deleteRoom(room.id)}
                                            className="px-3 py-1 text-sm bg-red-600 hover:bg-red-700 text-white rounded transition-colors"
                                        >
                                            삭제
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

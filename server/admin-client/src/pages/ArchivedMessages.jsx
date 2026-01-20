import { useState, useEffect } from 'react';
import { useNavigate } from 'react-router-dom';

export default function ArchivedMessages() {
    const [messages, setMessages] = useState([]);
    const [loading, setLoading] = useState(false);
    const [keyword, setKeyword] = useState('');
    const [userId, setUserId] = useState('');
    const navigate = useNavigate();

    const fetchMessages = async () => {
        setLoading(true);
        try {
            const token = localStorage.getItem('adminToken');
            const params = new URLSearchParams();
            if (keyword) params.append('keyword', keyword);
            if (userId) params.append('userId', userId);
            params.append('limit', 100);

            const res = await fetch(`/api/admin/archives/messages?${params}`, {
                headers: { Authorization: `Bearer ${token}` }
            });
            if (res.status === 401) return navigate('/login');
            const data = await res.json();
            setMessages(data);
        } catch (error) {
            console.error('Failed to fetch archived messages:', error);
        } finally {
            setLoading(false);
        }
    };

    useEffect(() => {
        fetchMessages();
    }, []);

    const handleSearch = (e) => {
        e.preventDefault();
        fetchMessages();
    };

    return (
        <div className='space-y-6'>
            <div className='flex justify-between items-center'>
                <h1 className='text-3xl font-bold bg-gradient-to-r from-blue-400 to-purple-500 bg-clip-text text-transparent'>
                    아카이브 메시지 (6개월)
                </h1>
                <div className='flex space-x-2'>
                    <form onSubmit={handleSearch} className='flex space-x-2'>
                        <input
                            type='text'
                            placeholder='유저 ID 검색'
                            className='px-4 py-2 bg-gray-800 border border-gray-700 rounded-lg text-white'
                            value={userId}
                            onChange={(e) => setUserId(e.target.value)}
                        />
                        <input
                            type='text'
                            placeholder='내용 키워드'
                            className='px-4 py-2 bg-gray-800 border border-gray-700 rounded-lg text-white'
                            value={keyword}
                            onChange={(e) => setKeyword(e.target.value)}
                        />
                        <button
                            type='submit'
                            className='px-4 py-2 bg-blue-600 hover:bg-blue-500 rounded-lg font-medium transition-colors'
                        >
                            검색
                        </button>
                    </form>
                </div>
            </div>

            <div className='bg-gray-800 rounded-xl border border-gray-700 overflow-hidden shadow-xl'>
                <div className='overflow-x-auto'>
                    <table className='w-full text-left'>
                        <thead>
                            <tr className='bg-gray-900/50 border-b border-gray-700'>
                                <th className='p-4 text-gray-400 font-medium w-32'>발송 시간</th>
                                <th className='p-4 text-gray-400 font-medium w-40'>방 이름</th>
                                <th className='p-4 text-gray-400 font-medium w-32'>닉네임</th>
                                <th className='p-4 text-gray-400 font-medium w-20'>타입</th>
                                <th className='p-4 text-gray-400 font-medium'>내용</th>
                                <th className='p-4 text-gray-400 font-medium w-32'>아카이브 일시</th>
                            </tr>
                        </thead>
                        <tbody className='divide-y divide-gray-700'>
                            {loading ? (
                                <tr>
                                    <td colSpan='6' className='p-8 text-center text-gray-400'>
                                        <div className='animate-spin w-8 h-8 border-4 border-blue-500 border-t-transparent rounded-full mx-auto mb-4'></div>
                                        로딩 중...
                                    </td>
                                </tr>
                            ) : messages.length === 0 ? (
                                <tr>
                                    <td colSpan='6' className='p-8 text-center text-gray-500'>
                                        아카이브된 데이터가 없습니다.
                                    </td>
                                </tr>
                            ) : (
                                messages.map((msg) => (
                                    <tr key={msg.id} className='hover:bg-gray-700/30 transition-colors'>
                                        <td className='p-4 text-sm text-gray-300 whitespace-nowrap'>
                                            {new Date(msg.created_at).toLocaleString()}
                                        </td>
                                        <td className='p-4 text-sm text-blue-400 font-medium'>
                                            {msg.room_name || msg.room_id.slice(0, 8)}
                                        </td>
                                        <td className='p-4 text-sm font-medium text-white'>
                                            {msg.user_nickname || 'Unknown'}
                                        </td>
                                        <td className='p-4 text-xs'>
                                            <span className={`px-2 py-1 rounded-full ${msg.type === 'image' ? 'bg-purple-900/50 text-purple-300' : 'bg-gray-700 text-gray-300'
                                                }`}>
                                                {msg.type}
                                            </span>
                                        </td>
                                        <td className='p-4 text-sm text-gray-300 max-w-xs truncate'>
                                            {msg.type === 'image' ? (
                                                <a href={msg.image_url} target="_blank" rel="noopener noreferrer" className="text-blue-400 hover:underline">
                                                    [이미지]
                                                </a>
                                            ) : (
                                                msg.content
                                            )}
                                        </td>
                                        <td className='p-4 text-sm text-gray-500 whitespace-nowrap'>
                                            {new Date(msg.archived_at).toLocaleString()}
                                        </td>
                                    </tr>
                                ))
                            )}
                        </tbody>
                    </table>
                </div>
                <div className='p-4 border-t border-gray-700 bg-gray-900/30 text-xs text-gray-500'>
                    * 아카이브 데이터는 6개월 후 영구 삭제됩니다.
                </div>
            </div>
        </div>
    );
}

import { Link, useLocation, useNavigate } from 'react-router-dom';

export default function Layout({ children }) {
    const location = useLocation();
    const navigate = useNavigate();

    const handleLogout = () => {
        localStorage.removeItem('adminToken');
        navigate('/login');
    };

    const navItems = [
        { path: '/', label: '대시보드', icon: '📊' },
        { path: '/rooms', label: '방 관리', icon: '💬' },
        { path: '/users', label: '사용자', icon: '👥' },
        { path: '/appeals', label: '소명 관리', icon: '⚖️' }, // Added
        { path: '/blocks', label: '차단 목록', icon: '🚫' },
        { path: '/reports', label: '신고 내역', icon: '🚨' },
        { path: '/logs', label: '서버 로그', icon: '📜' },
        { path: '/push-logs', label: '푸시 로그', icon: '📨' },
        { path: '/settings', label: '정책 설정', icon: '⚙️' },
    ];

    return (
        <div className="min-h-screen bg-gray-900 text-gray-100 flex">
            {/* Sidebar */}
            <aside className="w-64 bg-gray-800 border-r border-gray-700 flex flex-col fixed h-full">
                <div className="p-6 border-b border-gray-700">
                    <h1 className="text-xl font-bold bg-gradient-to-r from-blue-400 to-purple-500 bg-clip-text text-transparent">
                        YEO.PE Admin
                    </h1>
                </div>

                <nav className="flex-1 p-4 space-y-2 overflow-y-auto">
                    {navItems.map((item) => (
                        <Link
                            key={item.path}
                            to={item.path}
                            className={`flex items-center space-x-3 px-4 py-3 rounded-lg transition-all ${location.pathname === item.path
                                ? 'bg-blue-600 text-white shadow-lg shadow-blue-900/50'
                                : 'text-gray-400 hover:bg-gray-700 hover:text-white'
                                }`}
                        >
                            <span>{item.icon}</span>
                            <span className="font-medium">{item.label}</span>
                        </Link>
                    ))}
                </nav>

                <div className="p-4 border-t border-gray-700">
                    <button
                        onClick={handleLogout}
                        className="w-full flex items-center justify-center space-x-2 px-4 py-2 bg-gray-700 hover:bg-red-600 rounded-lg text-gray-300 hover:text-white transition-colors"
                    >
                        <span>🚪</span>
                        <span>로그아웃</span>
                    </button>
                    <div className="mt-4 text-center text-xs text-gray-600">
                        v1.0.0
                    </div>
                </div>
            </aside>

            {/* Main Content */}
            <main className="flex-1 ml-64 bg-gray-900 min-h-screen">
                <div className="p-8 max-w-7xl mx-auto">
                    {children}
                </div>
            </main>
        </div>
    );
}

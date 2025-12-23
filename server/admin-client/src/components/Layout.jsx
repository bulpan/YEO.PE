import { Link, useLocation, useNavigate } from 'react-router-dom';

export default function Layout({ children }) {
    const location = useLocation();
    const navigate = useNavigate();

    const menu = [
        { name: 'Dashboard', path: '/' },
        { name: 'Rooms', path: '/rooms' },
        { name: 'Users', path: '/users' },
        { name: 'Server Console', path: '/logs' },
    ];

    const handleLogout = () => {
        localStorage.removeItem('adminToken');
        navigate('/login');
    };

    return (
        <div className="flex min-h-screen bg-gray-900 text-gray-100">
            {/* Sidebar */}
            <aside className="w-64 bg-gray-800 border-r border-gray-700 flex flex-col">
                <div className="p-6">
                    <h1 className="text-2xl font-bold text-blue-400 tracking-wider">YEO.PE</h1>
                    <p className="text-xs text-gray-500 mt-1">ADMIN CONSOLE</p>
                </div>

                <nav className="flex-1 px-4 space-y-2">
                    {menu.map((item) => {
                        const isActive = location.pathname === item.path;
                        return (
                            <Link
                                key={item.path}
                                to={item.path}
                                className={`block px-4 py-3 rounded-lg transition-colors ${isActive
                                    ? 'bg-blue-600 text-white shadow-lg'
                                    : 'text-gray-400 hover:bg-gray-700 hover:text-white'
                                    }`}
                            >
                                {item.name}
                            </Link>
                        );
                    })}
                </nav>

                <div className="p-4 border-t border-gray-700">
                    <button
                        onClick={handleLogout}
                        className="w-full px-4 py-2 text-sm text-red-400 hover:bg-red-500/10 rounded-lg transition-colors"
                    >
                        로그아웃
                    </button>
                </div>
            </aside>

            {/* Main Content */}
            <main className="flex-1 overflow-auto">
                <header className="h-16 bg-gray-800/50 backdrop-blur border-b border-gray-700 flex items-center justify-between px-8 sticky top-0 z-10">
                    <h2 className="text-lg font-semibold text-white">
                        {menu.find(m => m.path === location.pathname)?.name || 'Admin'}
                    </h2>
                    <div className="text-sm text-gray-400">
                        {new Date().toLocaleDateString()}
                    </div>
                </header>

                <div className="p-8">
                    {children}
                </div>
            </main>
        </div>
    );
}

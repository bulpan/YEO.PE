import { BrowserRouter, Routes, Route, Navigate } from 'react-router-dom';
import Login from './pages/Login';
import Dashboard from './pages/Dashboard';
import Rooms from './pages/Rooms';
import RoomDetail from './pages/RoomDetail';
import Logs from './pages/Logs';
import PushLogs from './pages/PushLogs';
import Reports from './pages/Reports';
import Users from './pages/Users';
import BlockedUsers from './pages/BlockedUsers';
import Appeals from './pages/Appeals';
import Settings from './pages/Settings';
import Layout from './components/Layout';

function PrivateRoute({ children }) {
  const token = localStorage.getItem('adminToken');
  return token ? <Layout>{children}</Layout> : <Navigate to="/login" />;
}

export default function App() {
  return (
    <BrowserRouter basename="/admin">
      <Routes>
        <Route path="/login" element={<Login />} />

        <Route path="/" element={
          <PrivateRoute>
            <Dashboard />
          </PrivateRoute>
        } />

        <Route path="/rooms" element={
          <PrivateRoute>
            <Rooms />
          </PrivateRoute>
        } />

        <Route path="/rooms/:id" element={
          <PrivateRoute>
            <RoomDetail />
          </PrivateRoute>
        } />

        <Route path="/users" element={
          <PrivateRoute>
            <Users />
          </PrivateRoute>
        } />

        <Route path="/blocks" element={
          <PrivateRoute>
            <BlockedUsers />
          </PrivateRoute>
        } />

        <Route path="/reports" element={
          <PrivateRoute>
            <Reports />
          </PrivateRoute>
        } />

        <Route path="/logs" element={
          <PrivateRoute>
            <Logs />
          </PrivateRoute>
        } />

        <Route path="/appeals" element={
          <PrivateRoute>
            <Appeals />
          </PrivateRoute>
        } />

        <Route path="/push-logs" element={
          <PrivateRoute>
            <PushLogs />
          </PrivateRoute>
        } />

        <Route path="/settings" element={
          <PrivateRoute>
            <Settings />
          </PrivateRoute>
        } />
      </Routes>
    </BrowserRouter>
  );
}

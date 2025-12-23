import { BrowserRouter, Routes, Route, Navigate } from 'react-router-dom';
import Login from './pages/Login';
import Dashboard from './pages/Dashboard';
import Rooms from './pages/Rooms';
import RoomDetail from './pages/RoomDetail';
import Users from './pages/Users';
import Logs from './pages/Logs';
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

        <Route path="/logs" element={
          <PrivateRoute>
            <Logs />
          </PrivateRoute>
        } />
      </Routes>
    </BrowserRouter>
  );
}

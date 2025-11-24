import { useEffect } from 'react';
import { useNavigate } from 'react-router-dom';
import ProfileEditor from '../components/ProfileEditor';

export default function Dashboard() {
  const navigate = useNavigate();
  const user = JSON.parse(localStorage.getItem('user') || '{}');

  useEffect(() => {
    if (!localStorage.getItem('token')) {
      navigate('/login');
    }
  }, [navigate]);

  return (
    <div className="min-h-screen bg-gray-100 py-8">
      <div className="max-w-6xl mx-auto px-4">
        <div className="bg-blue-600 text-white rounded-lg p-4 mb-6 flex justify-between items-center">
          <div>
            <h1 className="text-2xl font-bold">ControlD Profile Manager</h1>
            <p className="text-sm opacity-90">Endpoint: {user.endpointId}</p>
          </div>
          <button
            onClick={() => {
              localStorage.clear();
              navigate('/login');
            }}
            className="bg-red-500 hover:bg-red-600 px-4 py-2 rounded font-medium"
          >
            Logout
          </button>
        </div>

        <ProfileEditor />
      </div>
    </div>
  );
}
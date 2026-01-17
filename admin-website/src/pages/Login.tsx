import { useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { api } from '../api';
import Button from '../components/Button';
import Input from '../components/Input';

function Login() {
  const navigate = useNavigate();
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [error, setError] = useState('');
  const [isLoading, setIsLoading] = useState(false);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setError('');
    setIsLoading(true);

    try {
      await api.login({ email, password });
      
      // Check if admin
      if (email.toLowerCase() !== 'admin@pastee.im') {
        api.logout();
        setError('Access denied. Admin privileges required.');
        setIsLoading(false);
        return;
      }
      
      navigate('/dashboard');
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Login failed');
    } finally {
      setIsLoading(false);
    }
  };

  return (
    <div className="min-h-screen flex items-center justify-center p-4">
      <div className="w-full max-w-md">
        {/* Header */}
        <div className="text-center mb-8">
          <div className="flex items-center justify-center gap-3 mb-4">
            <span className="text-4xl">🛠</span>
          </div>
          <h1 className="text-3xl font-bold text-white mb-2">Pastee Admin</h1>
          <p className="text-gray-400">Sign in to access the admin dashboard</p>
        </div>

        {/* Form */}
        <form onSubmit={handleSubmit} className="bg-dark-300 rounded-xl p-8 shadow-xl">
          {error && (
            <div className="mb-6 p-4 bg-red-500/10 border border-red-500/30 rounded-lg">
              <p className="text-red-400 text-sm text-center">{error}</p>
            </div>
          )}

          <div className="space-y-5">
            <Input
              label="Email"
              type="email"
              value={email}
              onChange={(e) => setEmail(e.target.value)}
              placeholder="admin@pastee.im"
              required
              autoFocus
            />

            <Input
              label="Password"
              type="password"
              value={password}
              onChange={(e) => setPassword(e.target.value)}
              placeholder="••••••••"
              required
            />
          </div>

          <Button
            type="submit"
            className="w-full mt-6"
            size="lg"
            isLoading={isLoading}
          >
            Sign In
          </Button>
        </form>

        {/* Footer */}
        <p className="text-center text-gray-500 text-sm mt-6">
          This area is restricted to administrators only.
        </p>
      </div>
    </div>
  );
}

export default Login;

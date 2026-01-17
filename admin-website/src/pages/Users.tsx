import { useState, useEffect, useCallback } from 'react';
import { api } from '../api';
import type { AdminUser } from '../types';
import Button from '../components/Button';
import Input from '../components/Input';
import Modal from '../components/Modal';

function Users() {
  const [users, setUsers] = useState<AdminUser[]>([]);
  const [total, setTotal] = useState(0);
  const [page, setPage] = useState(1);
  const [search, setSearch] = useState('');
  const [searchInput, setSearchInput] = useState('');
  const [isLoading, setIsLoading] = useState(true);
  const [error, setError] = useState('');
  
  // Modal state
  const [selectedUser, setSelectedUser] = useState<AdminUser | null>(null);
  const [showDeleteModal, setShowDeleteModal] = useState(false);
  const [showResetModal, setShowResetModal] = useState(false);
  const [newPassword, setNewPassword] = useState('');
  const [isProcessing, setIsProcessing] = useState(false);

  const pageSize = 20;

  const loadUsers = useCallback(async () => {
    setIsLoading(true);
    setError('');
    
    try {
      const response = await api.getUsers(page, pageSize, search);
      setUsers(response.users);
      setTotal(response.total);
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to load users');
    } finally {
      setIsLoading(false);
    }
  }, [page, search]);

  useEffect(() => {
    loadUsers();
  }, [loadUsers]);

  const handleSearch = (e: React.FormEvent) => {
    e.preventDefault();
    setPage(1);
    setSearch(searchInput);
  };

  const handleDelete = async () => {
    if (!selectedUser) return;
    
    setIsProcessing(true);
    try {
      await api.deleteUser(selectedUser.id);
      setShowDeleteModal(false);
      setSelectedUser(null);
      loadUsers();
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to delete user');
    } finally {
      setIsProcessing(false);
    }
  };

  const handleResetPassword = async () => {
    if (!selectedUser) return;
    
    setIsProcessing(true);
    try {
      const result = await api.resetUserPassword(selectedUser.id);
      setNewPassword(result.new_password);
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to reset password');
      setShowResetModal(false);
    } finally {
      setIsProcessing(false);
    }
  };

  const totalPages = Math.ceil(total / pageSize);

  const formatDate = (dateStr: string) => {
    if (!dateStr) return '-';
    const date = new Date(dateStr);
    return date.toLocaleDateString('en-US', {
      year: 'numeric',
      month: 'short',
      day: 'numeric',
    });
  };

  return (
    <div>
      <h1 className="text-2xl font-bold text-white mb-8">Users</h1>

      {/* Search */}
      <form onSubmit={handleSearch} className="flex gap-4 mb-6">
        <div className="flex-1">
          <Input
            type="text"
            placeholder="Search by email..."
            value={searchInput}
            onChange={(e) => setSearchInput(e.target.value)}
          />
        </div>
        <Button type="submit">Search</Button>
      </form>

      {/* Error */}
      {error && (
        <div className="mb-6 p-4 bg-red-500/10 border border-red-500/30 rounded-lg">
          <p className="text-red-400">{error}</p>
        </div>
      )}

      {/* Users Table */}
      <div className="bg-dark-300 rounded-xl overflow-hidden mb-6">
        {isLoading ? (
          <div className="flex items-center justify-center h-64">
            <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-primary-500"></div>
          </div>
        ) : (
          <div className="overflow-x-auto">
            <table>
              <thead>
                <tr>
                  <th>ID</th>
                  <th>Email</th>
                  <th>Created</th>
                  <th>Last Active</th>
                  <th>Verified</th>
                  <th>Actions</th>
                </tr>
              </thead>
              <tbody>
                {users.map((user) => (
                  <tr key={user.id}>
                    <td className="text-gray-400">{user.id}</td>
                    <td className="text-white font-medium">{user.email}</td>
                    <td className="text-gray-400">{formatDate(user.created_at)}</td>
                    <td className="text-gray-400">{formatDate(user.last_active)}</td>
                    <td>
                      {user.is_verified ? (
                        <span className="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-green-500/20 text-green-400">
                          ✓ Verified
                        </span>
                      ) : (
                        <span className="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-gray-500/20 text-gray-400">
                          Pending
                        </span>
                      )}
                    </td>
                    <td>
                      <div className="flex items-center gap-2">
                        <Button
                          variant="ghost"
                          size="sm"
                          onClick={() => {
                            setSelectedUser(user);
                            setNewPassword('');
                            setShowResetModal(true);
                          }}
                          title="Reset Password"
                        >
                          🔑
                        </Button>
                        <Button
                          variant="ghost"
                          size="sm"
                          onClick={() => {
                            setSelectedUser(user);
                            setShowDeleteModal(true);
                          }}
                          title="Delete User"
                          className="hover:text-red-400"
                        >
                          🗑
                        </Button>
                      </div>
                    </td>
                  </tr>
                ))}
                {users.length === 0 && (
                  <tr>
                    <td colSpan={6} className="text-center text-gray-500 py-8">
                      No users found
                    </td>
                  </tr>
                )}
              </tbody>
            </table>
          </div>
        )}
      </div>

      {/* Pagination */}
      {totalPages > 1 && (
        <div className="flex items-center justify-center gap-4">
          <Button
            variant="secondary"
            onClick={() => setPage((p) => Math.max(1, p - 1))}
            disabled={page === 1}
          >
            ← Previous
          </Button>
          <span className="text-gray-400">
            Page {page} of {totalPages} ({total} users)
          </span>
          <Button
            variant="secondary"
            onClick={() => setPage((p) => Math.min(totalPages, p + 1))}
            disabled={page === totalPages}
          >
            Next →
          </Button>
        </div>
      )}

      {/* Delete Confirmation Modal */}
      <Modal
        isOpen={showDeleteModal}
        onClose={() => setShowDeleteModal(false)}
        title="Delete User"
      >
        <p className="text-gray-300 mb-6">
          Are you sure you want to delete user <strong className="text-white">{selectedUser?.email}</strong>? This action cannot be undone.
        </p>
        <div className="flex justify-end gap-3">
          <Button variant="secondary" onClick={() => setShowDeleteModal(false)}>
            Cancel
          </Button>
          <Button variant="danger" onClick={handleDelete} isLoading={isProcessing}>
            Delete User
          </Button>
        </div>
      </Modal>

      {/* Reset Password Modal */}
      <Modal
        isOpen={showResetModal}
        onClose={() => {
          setShowResetModal(false);
          setNewPassword('');
        }}
        title="Reset Password"
      >
        {newPassword ? (
          <div>
            <p className="text-gray-300 mb-4">
              New password for <strong className="text-white">{selectedUser?.email}</strong>:
            </p>
            <div className="bg-dark-400 rounded-lg p-4 mb-6">
              <code className="text-green-400 text-lg break-all">{newPassword}</code>
            </div>
            <p className="text-sm text-gray-500 mb-6">
              Make sure to copy this password. It will not be shown again.
            </p>
            <Button className="w-full" onClick={() => {
              navigator.clipboard.writeText(newPassword);
            }}>
              Copy Password
            </Button>
          </div>
        ) : (
          <>
            <p className="text-gray-300 mb-6">
              Reset password for <strong className="text-white">{selectedUser?.email}</strong>?
            </p>
            <div className="flex justify-end gap-3">
              <Button variant="secondary" onClick={() => setShowResetModal(false)}>
                Cancel
              </Button>
              <Button onClick={handleResetPassword} isLoading={isProcessing}>
                Reset Password
              </Button>
            </div>
          </>
        )}
      </Modal>
    </div>
  );
}

export default Users;

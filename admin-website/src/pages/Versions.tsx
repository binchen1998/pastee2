import { useState, useEffect } from 'react';
import { api } from '../api';
import type { VersionInfo } from '../types';
import Button from '../components/Button';
import Input from '../components/Input';
import Modal from '../components/Modal';

function Versions() {
  const [versions, setVersions] = useState<VersionInfo[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const [error, setError] = useState('');
  const [successMessage, setSuccessMessage] = useState('');

  // Form state
  const [version, setVersion] = useState('');
  const [downloadUrl, setDownloadUrl] = useState('');
  const [releaseNotes, setReleaseNotes] = useState('');
  const [isMandatory, setIsMandatory] = useState(false);
  const [isSubmitting, setIsSubmitting] = useState(false);

  // Delete modal
  const [selectedVersion, setSelectedVersion] = useState<VersionInfo | null>(null);
  const [showDeleteModal, setShowDeleteModal] = useState(false);
  const [isDeleting, setIsDeleting] = useState(false);

  useEffect(() => {
    loadVersions();
  }, []);

  const loadVersions = async () => {
    setIsLoading(true);
    setError('');
    
    try {
      const response = await api.getVersions();
      setVersions(response);
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to load versions');
    } finally {
      setIsLoading(false);
    }
  };

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setError('');
    setSuccessMessage('');
    setIsSubmitting(true);

    try {
      await api.createVersion({
        version,
        download_url: downloadUrl,
        release_notes: releaseNotes,
        is_mandatory: isMandatory,
      });
      
      // Clear form
      setVersion('');
      setDownloadUrl('');
      setReleaseNotes('');
      setIsMandatory(false);
      
      setSuccessMessage('Version published successfully!');
      loadVersions();
      
      // Clear success message after 3s
      setTimeout(() => setSuccessMessage(''), 3000);
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to publish version');
    } finally {
      setIsSubmitting(false);
    }
  };

  const handleDelete = async () => {
    if (!selectedVersion) return;
    
    setIsDeleting(true);
    try {
      await api.deleteVersion(selectedVersion.id);
      setShowDeleteModal(false);
      setSelectedVersion(null);
      setSuccessMessage('Version deleted successfully!');
      loadVersions();
      
      setTimeout(() => setSuccessMessage(''), 3000);
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to delete version');
    } finally {
      setIsDeleting(false);
    }
  };

  const formatDate = (dateStr: string) => {
    if (!dateStr) return '-';
    const date = new Date(dateStr);
    return date.toLocaleDateString('en-US', {
      year: 'numeric',
      month: 'short',
      day: 'numeric',
      hour: '2-digit',
      minute: '2-digit',
    });
  };

  return (
    <div>
      <h1 className="text-2xl font-bold text-white mb-8">Versions</h1>

      {/* Messages */}
      {error && (
        <div className="mb-6 p-4 bg-red-500/10 border border-red-500/30 rounded-lg">
          <p className="text-red-400">{error}</p>
        </div>
      )}
      
      {successMessage && (
        <div className="mb-6 p-4 bg-green-500/10 border border-green-500/30 rounded-lg">
          <p className="text-green-400">{successMessage}</p>
        </div>
      )}

      {/* Publish Form */}
      <div className="bg-dark-300 rounded-xl p-6 mb-8">
        <h2 className="text-lg font-semibold text-white mb-6">Publish New Version</h2>
        
        <form onSubmit={handleSubmit}>
          <div className="grid grid-cols-1 md:grid-cols-2 gap-6 mb-6">
            <Input
              label="Version"
              placeholder="e.g., 1.2.0"
              value={version}
              onChange={(e) => setVersion(e.target.value)}
              required
            />
            <Input
              label="Download URL"
              placeholder="https://..."
              value={downloadUrl}
              onChange={(e) => setDownloadUrl(e.target.value)}
              required
            />
          </div>
          
          <div className="mb-6">
            <label className="block text-sm text-gray-400 mb-1.5">Release Notes</label>
            <textarea
              className="w-full px-4 py-2.5 bg-dark-400 border border-dark-200 rounded-lg text-white placeholder-gray-500 focus:border-primary-500 transition-colors resize-none"
              rows={4}
              placeholder="What's new in this version..."
              value={releaseNotes}
              onChange={(e) => setReleaseNotes(e.target.value)}
            />
          </div>

          <div className="flex items-center justify-between">
            <label className="flex items-center gap-3 cursor-pointer">
              <input
                type="checkbox"
                checked={isMandatory}
                onChange={(e) => setIsMandatory(e.target.checked)}
                className="w-5 h-5 rounded bg-dark-400 border-dark-200 text-primary-500 focus:ring-primary-500 focus:ring-offset-dark-300"
              />
              <span className="text-gray-300">Mandatory Update</span>
            </label>
            
            <Button type="submit" isLoading={isSubmitting}>
              Publish Version
            </Button>
          </div>
        </form>
      </div>

      {/* Versions List */}
      <div className="bg-dark-300 rounded-xl overflow-hidden">
        <div className="p-6 border-b border-dark-200">
          <h2 className="text-lg font-semibold text-white">Published Versions</h2>
        </div>

        {isLoading ? (
          <div className="flex items-center justify-center h-48">
            <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-primary-500"></div>
          </div>
        ) : (
          <div className="overflow-x-auto">
            <table>
              <thead>
                <tr>
                  <th>Version</th>
                  <th>Release Notes</th>
                  <th>Mandatory</th>
                  <th>Created</th>
                  <th>Actions</th>
                </tr>
              </thead>
              <tbody>
                {versions.map((ver) => (
                  <tr key={ver.id}>
                    <td>
                      <span className="text-white font-mono font-medium">{ver.version}</span>
                    </td>
                    <td className="max-w-xs">
                      <p className="text-gray-400 truncate" title={ver.release_notes}>
                        {ver.release_notes || '-'}
                      </p>
                    </td>
                    <td>
                      {ver.is_mandatory ? (
                        <span className="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-red-500/20 text-red-400">
                          Required
                        </span>
                      ) : (
                        <span className="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-gray-500/20 text-gray-400">
                          Optional
                        </span>
                      )}
                    </td>
                    <td className="text-gray-400">{formatDate(ver.created_at)}</td>
                    <td>
                      <div className="flex items-center gap-2">
                        <a
                          href={ver.download_url}
                          target="_blank"
                          rel="noopener noreferrer"
                          className="text-primary-400 hover:text-primary-300"
                          title="Download"
                        >
                          ⬇
                        </a>
                        <Button
                          variant="ghost"
                          size="sm"
                          onClick={() => {
                            setSelectedVersion(ver);
                            setShowDeleteModal(true);
                          }}
                          title="Delete Version"
                          className="hover:text-red-400"
                        >
                          🗑
                        </Button>
                      </div>
                    </td>
                  </tr>
                ))}
                {versions.length === 0 && (
                  <tr>
                    <td colSpan={5} className="text-center text-gray-500 py-8">
                      No versions published yet
                    </td>
                  </tr>
                )}
              </tbody>
            </table>
          </div>
        )}
      </div>

      {/* Delete Confirmation Modal */}
      <Modal
        isOpen={showDeleteModal}
        onClose={() => setShowDeleteModal(false)}
        title="Delete Version"
      >
        <p className="text-gray-300 mb-6">
          Are you sure you want to delete version <strong className="text-white font-mono">{selectedVersion?.version}</strong>? This action cannot be undone.
        </p>
        <div className="flex justify-end gap-3">
          <Button variant="secondary" onClick={() => setShowDeleteModal(false)}>
            Cancel
          </Button>
          <Button variant="danger" onClick={handleDelete} isLoading={isDeleting}>
            Delete Version
          </Button>
        </div>
      </Modal>
    </div>
  );
}

export default Versions;

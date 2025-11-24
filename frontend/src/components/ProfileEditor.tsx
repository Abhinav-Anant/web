import { useState, useEffect } from 'react';
import { getProfile, updateProfile } from '../services/api';

export default function ProfileEditor() {
  const [profile, setProfile] = useState<any>(null);
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState('');
  const [success, setSuccess] = useState('');

  useEffect(() => {
    loadProfile();
  }, []);

  const loadProfile = async () => {
    try {
      const data = await getProfile();
      setProfile(data.profile);
    } catch (err: any) {
      setError(err.message || 'Failed to load profile');
    } finally {
      setLoading(false);
    }
  };

  const handleSave = async () => {
    setSaving(true);
    setError('');
    setSuccess('');

    try {
      await updateProfile({ profile });
      setSuccess('✅ Profile updated successfully! Changes take effect within 60 seconds.');
      setTimeout(() => setSuccess(''), 5000);
    } catch (err: any) {
      setError(err.message || 'Failed to update profile');
    } finally {
      setSaving(false);
    }
  };

  if (loading) return <div className="text-center py-8">Loading profile...</div>;
  if (!profile) return <div className="text-center py-8 text-red-600">Error loading profile</div>;

  return (
    <div className="space-y-6">
      {error && (
        <div className="bg-red-100 border border-red-400 text-red-700 px-4 py-3 rounded">
          {error}
        </div>
      )}
      
      {success && (
        <div className="bg-green-100 border border-green-400 text-green-700 px-4 py-3 rounded">
          {success}
        </div>
      )}

      <div className="bg-white rounded-lg shadow p-6">
        <h3 className="text-xl font-bold mb-4">Profile Information</h3>
        
        <div className="grid md:grid-cols-2 gap-4">
          <div>
            <label className="block text-sm font-medium text-gray-700 mb-1">Endpoint ID</label>
            <input
              type="text"
              value={profile.profile_id}
              disabled
              className="w-full px-3 py-2 bg-gray-100 border rounded cursor-not-allowed"
            />
          </div>
          
          <div>
            <label className="block text-sm font-medium text-gray-700 mb-1">Profile Name</label>
            <input
              type="text"
              value={profile.name || ''}
              onChange={(e) => setProfile({...profile, name: e.target.value})}
              className="w-full px-3 py-2 border rounded focus:ring-2 focus:ring-blue-500"
            />
          </div>
        </div>

        <div className="mt-4">
          <label className="block text-sm font-medium text-gray-700 mb-1">Description</label>
          <textarea
            value={profile.description || ''}
            onChange={(e) => setProfile({...profile, description: e.target.value})}
            className="w-full px-3 py-2 border rounded focus:ring-2 focus:ring-blue-500"
            rows={2}
          />
        </div>
      </div>

      <div className="bg-white rounded-lg shadow p-6">
        <h3 className="text-xl font-bold mb-4">Security & Filters</h3>
        
        <div className="grid md:grid-cols-2 gap-4">
          {Object.entries({
            malware: 'Block Malware',
            ads: 'Block Ads',
            social: 'Block Social Media',
            porn: 'Block Adult Content',
            gambling: 'Block Gambling',
            drugs: 'Block Drugs',
            ransomware: 'Block Ransomware',
            cryptojacking: 'Block Cryptojacking'
          }).map(([key, label]) => (
            <label key={key} className="flex items-center p-2 hover:bg-gray-50 rounded">
              <input
                type="checkbox"
                checked={profile.filters?.[key] || false}
                onChange={(e) => setProfile({
                  ...profile,
                  filters: {...profile.filters, [key]: e.target.checked}
                })}
                className="mr-3 h-4 w-4"
              />
              <span>{label}</span>
            </label>
          ))}
        </div>
      </div>

      <div className="bg-white rounded-lg shadow p-6">
        <h3 className="text-xl font-bold mb-4">DNS Settings</h3>
        
        <div className="grid md:grid-cols-2 gap-4">
          <label className="flex items-center p-2 hover:bg-gray-50 rounded">
            <input
              type="checkbox"
              checked={profile.settings?.dnssec || false}
              onChange={(e) => setProfile({
                ...profile,
                settings: {...profile.settings, dnssec: e.target.checked}
              })}
              className="mr-3 h-4 w-4"
            />
            <span>Enable DNSSEC</span>
          </label>

          <label className="flex items-center p-2 hover:bg-gray-50 rounded">
            <input
              type="checkbox"
              checked={profile.settings?.ecs !== false}
              onChange={(e) => setProfile({
                ...profile,
                settings: {...profile.settings, ecs: e.target.checked}
              })}
              className="mr-3 h-4 w-4"
            />
            <span>Enable EDNS Client Subnet</span>
          </label>
        </div>
      </div>

      <div className="bg-white rounded-lg shadow p-6">
        <h3 className="text-xl font-bold mb-4">Custom Rules</h3>
        
        <div className="mb-4">
          <label className="block text-sm font-medium text-gray-700 mb-1">
            🚫 Blocklist Domains (one per line)
          </label>
          <textarea
            value={(profile.blocklist || []).join('\n')}
            onChange={(e) => setProfile({
              ...profile,
              blocklist: e.target.value.split('\n').filter(d => d.trim())
            })}
            className="w-full px-3 py-2 border rounded font-mono text-sm"
            rows={5}
            placeholder="example.com&#10;ads.example.com&#10;tracking.com"
          />
          <p className="text-xs text-gray-500 mt-1">Enter domains to block. Example: malware.com</p>
        </div>

        <div>
          <label className="block text-sm font-medium text-gray-700 mb-1">
            ✅ Allowlist Domains (one per line)
          </label>
          <textarea
            value={(profile.allowlist || []).join('\n')}
            onChange={(e) => setProfile({
              ...profile,
              allowlist: e.target.value.split('\n').filter(d => d.trim())
            })}
            className="w-full px-3 py-2 border rounded font-mono text-sm"
            rows={5}
            placeholder="important-site.com&#10;whitelisted.com"
          />
          <p className="text-xs text-gray-500 mt-1">Overrides blocklist. Example: company.com</p>
        </div>
      </div>

      <div className="flex justify-end">
        <button
          onClick={handleSave}
          disabled={saving}
          className="bg-blue-600 text-white py-3 px-8 rounded-lg hover:bg-blue-700 disabled:opacity-50 font-medium"
        >
          {saving ? '💾 Saving...' : '💾 Save Changes'}
        </button>
      </div>
    </div>
  );
}
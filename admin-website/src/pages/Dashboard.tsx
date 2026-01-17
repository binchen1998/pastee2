import { useState, useEffect } from 'react';
import { api } from '../api';
import type { DashboardResponse, DailyStats } from '../types';
import StatsCard from '../components/StatsCard';

function Dashboard() {
  const [data, setData] = useState<DashboardResponse | null>(null);
  const [isLoading, setIsLoading] = useState(true);
  const [error, setError] = useState('');

  useEffect(() => {
    loadDashboard();
  }, []);

  const loadDashboard = async () => {
    setIsLoading(true);
    setError('');
    
    try {
      const response = await api.getDashboard();
      setData(response);
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to load dashboard');
    } finally {
      setIsLoading(false);
    }
  };

  if (isLoading) {
    return (
      <div className="flex items-center justify-center h-64">
        <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-primary-500"></div>
      </div>
    );
  }

  if (error) {
    return (
      <div className="bg-red-500/10 border border-red-500/30 rounded-lg p-6 text-center">
        <p className="text-red-400">{error}</p>
        <button
          onClick={loadDashboard}
          className="mt-4 text-primary-400 hover:text-primary-300"
        >
          Try again
        </button>
      </div>
    );
  }

  // Calculate values from data
  const summary = data?.summary;
  const today = data?.today;
  const yesterday = data?.yesterday;
  const growthRates = data?.growth_rates;

  const totalUsers = summary?.total_users ?? today?.total_users ?? 0;
  const todayNew = summary?.today_registrations ?? today?.new_registrations ?? 0;
  const todayActive = summary?.today_active ?? today?.active_users ?? 0;
  const weekAvg = summary?.week_avg_registrations ?? 0;

  // Calculate changes
  let regChange: number | undefined;
  let activeChange: number | undefined;
  let changeType: 'percentage' | 'absolute' = 'absolute';

  if (growthRates) {
    regChange = growthRates.registrations;
    activeChange = growthRates.active_users;
    changeType = 'percentage';
  } else if (today && yesterday) {
    regChange = today.new_registrations - yesterday.new_registrations;
    activeChange = today.active_users - yesterday.active_users;
  }

  return (
    <div>
      <h1 className="text-2xl font-bold text-white mb-8">Dashboard</h1>

      {/* Stats Grid */}
      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6 mb-8">
        <StatsCard
          title="Total Users"
          value={totalUsers}
          icon="👥"
          color="blue"
        />
        <StatsCard
          title="Today New"
          value={todayNew}
          change={regChange}
          changeType={changeType}
          icon="✨"
          color="green"
        />
        <StatsCard
          title="Today Active"
          value={todayActive}
          change={activeChange}
          changeType={changeType}
          icon="🔥"
          color="purple"
        />
        <StatsCard
          title="Weekly Avg New"
          value={weekAvg.toFixed(1)}
          icon="📈"
          color="orange"
        />
      </div>

      {/* Trend Table */}
      <div className="bg-dark-300 rounded-xl overflow-hidden">
        <div className="p-6 border-b border-dark-200">
          <h2 className="text-lg font-semibold text-white">Last 7 Days Trend</h2>
        </div>
        
        <div className="overflow-x-auto">
          <table>
            <thead>
              <tr>
                <th>Date</th>
                <th>New Registrations</th>
                <th>Active Users</th>
                <th>Total Users</th>
              </tr>
            </thead>
            <tbody>
              {data?.recent_week?.map((day: DailyStats) => (
                <tr key={day.date}>
                  <td className="text-gray-300">{day.date}</td>
                  <td>
                    <span className="text-green-400 font-medium">
                      +{day.new_registrations}
                    </span>
                  </td>
                  <td>
                    <span className="text-purple-400 font-medium">
                      {day.active_users}
                    </span>
                  </td>
                  <td className="text-gray-400">{day.total_users.toLocaleString()}</td>
                </tr>
              ))}
              {(!data?.recent_week || data.recent_week.length === 0) && (
                <tr>
                  <td colSpan={4} className="text-center text-gray-500 py-8">
                    No data available
                  </td>
                </tr>
              )}
            </tbody>
          </table>
        </div>
      </div>
    </div>
  );
}

export default Dashboard;

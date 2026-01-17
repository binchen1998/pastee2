interface StatsCardProps {
  title: string;
  value: string | number;
  change?: number;
  changeType?: 'percentage' | 'absolute';
  icon?: string;
  color?: 'blue' | 'green' | 'orange' | 'purple';
}

function StatsCard({ title, value, change, changeType = 'absolute', icon, color = 'blue' }: StatsCardProps) {
  const colorClasses = {
    blue: 'text-primary-400',
    green: 'text-green-400',
    orange: 'text-orange-400',
    purple: 'text-purple-400',
  };

  const formatChange = () => {
    if (change === undefined) return null;
    
    const isPositive = change >= 0;
    const prefix = isPositive ? '+' : '';
    const suffix = changeType === 'percentage' ? '%' : '';
    const label = changeType === 'percentage' ? '' : ' vs yesterday';
    
    return (
      <span className={`text-sm ${isPositive ? 'text-green-400' : 'text-red-400'}`}>
        {prefix}{change.toFixed(changeType === 'percentage' ? 1 : 0)}{suffix}{label}
      </span>
    );
  };

  return (
    <div className="bg-dark-300 rounded-xl p-6">
      <div className="flex items-center justify-between mb-2">
        <span className="text-gray-400 text-sm">{title}</span>
        {icon && <span className="text-xl">{icon}</span>}
      </div>
      <div className="flex items-end gap-3">
        <span className={`text-3xl font-bold ${colorClasses[color]}`}>
          {typeof value === 'number' ? value.toLocaleString() : value}
        </span>
        {formatChange()}
      </div>
    </div>
  );
}

export default StatsCard;

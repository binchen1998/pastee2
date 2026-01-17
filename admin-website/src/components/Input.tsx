interface InputProps extends React.InputHTMLAttributes<HTMLInputElement> {
  label?: string;
  error?: string;
}

function Input({ label, error, className = '', ...props }: InputProps) {
  return (
    <div className="w-full">
      {label && (
        <label className="block text-sm text-gray-400 mb-1.5">{label}</label>
      )}
      <input
        className={`w-full px-4 py-2.5 bg-dark-400 border border-dark-200 rounded-lg text-white placeholder-gray-500 focus:border-primary-500 transition-colors ${
          error ? 'border-red-500' : ''
        } ${className}`}
        {...props}
      />
      {error && <p className="mt-1 text-sm text-red-400">{error}</p>}
    </div>
  );
}

export default Input;

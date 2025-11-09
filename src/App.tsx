import React from 'react';
import { Provider } from 'react-redux';
import { store } from './store';
import { AuthProvider, useAuth } from './components/AuthProvider';
import RegistrationWizard from './components/RegistrationWizard';
import LoginForm from './components/LoginForm';
import 'bootstrap/dist/css/bootstrap.min.css';

function AppContent() {
  const { user, loading } = useAuth();

  if (loading) {
    return (
      <div className="d-flex justify-content-center align-items-center min-vh-100">
        <div className="text-center">
          <div className="spinner-border" role="status">
            <span className="visually-hidden">Loading...</span>
          </div>
          <p className="mt-2">Loading...</p>
        </div>
      </div>
    );
  }

  if (!user) {
    return <LoginForm />;
  }

  return <RegistrationWizard />;
}

function App() {
  return (
    <Provider store={store}>
      <AuthProvider>
        <div className="App">
          <AppContent />
        </div>
      </AuthProvider>
    </Provider>
  );
}

export default App;

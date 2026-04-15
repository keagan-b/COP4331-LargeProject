import React from "react";
import { BrowserRouter, Routes, Route, Navigate } from "react-router-dom";
import LoginPage from "./pages/LoginPage";
import HomePage from "./pages/HomePage";
import SignupPage from "./pages/SignupPage";
import CategoryPage from "./pages/CategoryPage";
import CollectionPage from "./pages/CollectionPage";
import ResetPasswordPage from "./pages/ResetPasswordPage";
import { useTheme } from "./hooks/useTheme";

const PrivateRoute = ({ element }: { element: React.ReactElement }) => {
  const token = localStorage.getItem("token");
  return token ? element : <Navigate to="/login" replace />;
};

function App() {
  // Calling useTheme here ensures the data-theme attribute on <html> is always
  // in sync with localStorage, even when navigating between pages.
  useTheme();

  return (
    <BrowserRouter>
      <Routes>
        <Route path="/" element={<Navigate to="/login" replace />} />
        <Route path="/home" element={<PrivateRoute element={<HomePage />} />} />
        <Route path="/category/:categoryId" element={<PrivateRoute element={<CategoryPage />} />} />
        <Route path="/collection/:collectionId" element={<PrivateRoute element={<CollectionPage />} />} />
        <Route path="/login" element={<LoginPage />} />
        <Route path="/signup" element={<SignupPage />} />
        <Route path="/resetpassword" element={<ResetPasswordPage />} />
      </Routes>
    </BrowserRouter>
  );
}

export default App;

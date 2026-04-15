import React, { useState, useEffect } from "react";
import "./ResetPassword.css";

const ResetPassword: React.FC = () => {
  const [email, setEmail] = useState("");
  const [token, setToken] = useState("");
  const [newPassword, setNewPassword] = useState("");
  const [confirmPassword, setConfirmPassword] = useState("");
  const [message, setMessage] = useState("");
  const [hasToken, setHasToken] = useState(false);

  // On mount, check if a token is in the URL
  useEffect(() => {
    const params = new URLSearchParams(window.location.search);
    const urlToken = params.get("token");
    if (urlToken) {
      setToken(urlToken);
      setHasToken(true);
    }
  }, []);

  const requestReset = async () => {
    if (!email) { setMessage("Please enter your email."); return; }
    try {
      const res = await fetch(`/api/user/request-password-reset?email=${encodeURIComponent(email)}`);
      const text = await res.text();
      setMessage(text);
    } catch {
      setMessage("Unable to connect to server.");
    }
  };

  const handleReset = async () => {
    if (!newPassword) { setMessage("Please enter a new password."); return; }
    if (newPassword !== confirmPassword) { setMessage("Passwords do not match."); return; }
    try {
      const res = await fetch("/api/user/reset-password", {
        method: "PUT",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ token, newPassword }),
      });
      const data = await res.json();
      if (res.ok) {
        setMessage("Password reset successfully! Redirecting to login...");
        setTimeout(() => { window.location.href = "/login"; }, 1500);
      } else {
        setMessage(data.error || "Failed to reset password.");
      }
    } catch {
      setMessage("Unable to connect to server.");
    }
  };

  return (
    <div className="auth-container">
    <img src="/projectlogo.png" alt="Logo" className="login-logo" />

      <h1 className="title">Collector's Pair-A-Dice</h1>

      <div className="auth-box">
        <h2>Reset Password</h2>

        {/* Show request form only if no token in URL */}
        {!hasToken && (
          <>
            <label>Email</label>
            <input
              type="email"
              value={email}
              onChange={(e) => setEmail(e.target.value)}
              placeholder="Enter your email..."
            />
            <button onClick={requestReset}>Send Reset Email</button>
            <hr />
            <p style={{ fontSize: "0.85rem", color: "#7a8099", textAlign: "center" }}>
              Check your email for a reset link, then click it to continue.
            </p>
          </>
        )}

        {/* Show reset form only if token is present */}
        {hasToken && (
          <>
            <label>New Password</label>
            <input
              type="password"
              value={newPassword}
              onChange={(e) => setNewPassword(e.target.value)}
              placeholder="Enter new password..."
            />
            <label>Confirm Password</label>
            <input
              type="password"
              value={confirmPassword}
              onChange={(e) => setConfirmPassword(e.target.value)}
              placeholder="Confirm new password..."
            />
            <button onClick={handleReset}>Reset Password</button>
          </>
        )}

        {message && <p className="message">{message}</p>}
      </div>
    </div>
  );
};

export default ResetPassword;

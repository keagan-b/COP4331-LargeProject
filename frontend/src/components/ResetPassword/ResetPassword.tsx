import React, { useState } from "react";
import "./ResetPassword.css";

const ResetPassword: React.FC = () => {
  const [email, setEmail] = useState("");
  const [token, setToken] = useState("");
  const [newPassword, setNewPassword] = useState("");
  const [message, setMessage] = useState("");

  const requestReset = async () => {
    const res = await fetch("http://localhost:5000/api/user/reset", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
      },
      body: JSON.stringify({ email }),
    });

    const data = await res.json();
    setMessage(data.message || data.error || "Request sent");
  };

  const handleReset = async () => {
    const res = await fetch("http://localhost:5000/api/user/reset", {
      method: "PUT",
      headers: {
        "Content-Type": "application/json",
      },
      body: JSON.stringify({ token, newPassword }),
    });

    const data = await res.json();
    setMessage(data.message || data.error);

    if (res.ok) {
      setTimeout(() => {
        window.location.href = "/login";
      }, 1500);
    }
  };

  return (
    <div className="auth-container">
      <h1 className="title">Collecting Paradise</h1>

      <div className="auth-box">
        <h2>Reset Password</h2>

        <label>Email</label>
        <input type="email" onChange={(e) => setEmail(e.target.value)} />
        <button onClick={requestReset}>Request Reset</button>

        <hr />

        <label>Token</label>
        <input type="text" onChange={(e) => setToken(e.target.value)} />

        <label>New Password</label>
        <input type="password" onChange={(e) => setNewPassword(e.target.value)} />

        <button onClick={handleReset}>Reset Password</button>

        {message && <p className="message">{message}</p>}
      </div>
    </div>
  );
};

export default ResetPassword;
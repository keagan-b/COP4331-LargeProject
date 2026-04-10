import React, { useState } from "react";
import "./Login.css";
import { Link, useNavigate } from "react-router-dom";

const Login: React.FC = () => {
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [message, setMessage] = useState("");
  const navigate = useNavigate();

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();

    try {
      const res = await fetch("/api/user/login", {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
        },
        body: JSON.stringify({ email, password }),
      });

      const data = await res.json();
console.log("Login response:", data);

      if (!res.ok) {
        setMessage(data.error || "Something went wrong. Please try again.");
        return;
      }

      localStorage.setItem("token", data.sessionToken);
      setMessage("Login successful!");

      setTimeout(() => {
        navigate("/");
      }, 1000);
    } catch (err) {
      setMessage("Unable to connect to the server. Please try again later.");
    }
  };

  return (
    <div className="login-container">
      <h1 className="title">Collector's Pair-A-Dice</h1>

      <div className="login-box">
        <h2>Login</h2>

        <form onSubmit={handleSubmit}>
          <label>Email</label>
          <input
            type="email"
            value={email}
            onChange={(e) => setEmail(e.target.value)}
            required
          />

          <label>Password</label>
          <input
            type="password"
            value={password}
            onChange={(e) => setPassword(e.target.value)}
            required
          />

          <Link to="/resetpassword" className="forgot-password">
            Forgot Password
          </Link>

          <button type="submit">Log In</button>
        </form>

        {message && <p className="message">{message}</p>}

        <p className="signup-text">
          Don't have an account? <Link to="/signup">Sign Up</Link>
        </p>
      </div>
    </div>
  );
};

export default Login;
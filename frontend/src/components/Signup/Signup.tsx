import React, { useState } from "react";
import "./Signup.css";
import { Link } from "react-router-dom";

const Signup: React.FC = () => {
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [confirmPassword, setConfirmPassword] = useState("");
  const [message, setMessage] = useState("");
  const [isSuccess, setIsSuccess] = useState(false);

  const handleSignup = async (e: React.FormEvent) => {
    e.preventDefault();

    if (password !== confirmPassword) {
      setMessage("Passwords do not match");
      setIsSuccess(false);
      return;
    }

    try {
      const res = await fetch("/api/user/register", {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
        },
        body: JSON.stringify({ email, password }),
      });

      const data = await res.json();

      if (!res.ok) {
        setMessage(data.error || "Something went wrong. Please try again.");
        setIsSuccess(false);
        return;
      }

      setIsSuccess(true);
      setMessage(
        `Account created! A verification email has been sent to ${email}. Please check your inbox and verify your account before logging in.`
      );
    } catch (err) {
      setMessage("Unable to connect to the server. Please try again later.");
      setIsSuccess(false);
    }
  };

  return (
    <div className="auth-container">
      <h1 className="title">Collector's Pair-A-Dice</h1>

      <div className="auth-box">
        <h2>Sign Up</h2>

        {!isSuccess ? (
          <form onSubmit={handleSignup}>
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

            <label>Confirm Password</label>
            <input
              type="password"
              value={confirmPassword}
              onChange={(e) => setConfirmPassword(e.target.value)}
              required
            />

            <button type="submit">Create Account</button>

            {message && <p className="message error">{message}</p>}
          </form>
        ) : (
          <div className="verification-notice">
            <p className="message success">{message}</p>
            <p>Once verified, you can proceed to log in.</p>
          </div>
        )}

        <p className="switch-text">
          Already have an account? <Link to="/login">Log In</Link>
        </p>
      </div>
    </div>
  );
};

export default Signup;
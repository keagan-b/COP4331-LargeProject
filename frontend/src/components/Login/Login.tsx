import React, { useState, useRef, useEffect } from "react";
import "./Login.css";
import { Link, useNavigate } from "react-router-dom";
import { useTheme } from "../../hooks/useTheme";

const Login: React.FC = () => {
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [message, setMessage] = useState("");
  const navigate = useNavigate();
  const [isSuccess, setIsSuccess] = useState(false);
  const [theme, setTheme] = useTheme();
  // Separate "transitioning" flag so we can animate the scene in/out
  // independently from the theme value being committed.
  const [sceneVisible, setSceneVisible] = useState(theme === "tropical");
  const [transitionClass, setTransitionClass] = useState<"" | "entering" | "active" | "leaving">(
    theme === "tropical" ? "active" : ""
  );
  const audioRef = useRef<HTMLAudioElement | null>(null);

  useEffect(() => {
    audioRef.current = new Audio("/tropical.mp3");
    audioRef.current.loop = true;
    audioRef.current.volume = 0.5;
    return () => { audioRef.current?.pause(); };
  }, []);

  // If arriving on the page already in tropical mode, sync audio
  useEffect(() => {
    if (theme === "tropical") {
      audioRef.current?.play().catch(() => {});
    }
  }, []);

  const handleLogoClick = () => {
    if (theme === "tropical") {
      // Start leave transition
      setTransitionClass("leaving");
      audioRef.current?.pause();
      if (audioRef.current) audioRef.current.currentTime = 0;
      setTimeout(() => {
        setTheme("default");
        setSceneVisible(false);
        setTransitionClass("");
      }, 900); // matches CSS transition duration
    } else {
      // Start enter transition — mount scene first, then animate in
      setTheme("tropical");
      setSceneVisible(true);
      setTransitionClass("entering");
      audioRef.current?.play().catch(() => {});
      // Let the DOM paint, then trigger "active" for CSS transition
      requestAnimationFrame(() => {
        requestAnimationFrame(() => {
          setTransitionClass("active");
        });
      });
    }
  };

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    try {
      const res = await fetch("/api/user/login", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ email, password }),
      });
      const data = await res.json();
      if (!res.ok) {
        setMessage(data.error || "Something went wrong. Please try again.");
        setIsSuccess(false);
        return;
      }
      localStorage.setItem("token", data.sessionToken);
      setMessage("Login successful!");
      setIsSuccess(true);
      setTimeout(() => navigate("/home"), 1000);
    } catch {
      setMessage("Unable to connect to the server. Please try again later.");
    }
  };

  const isTropical = theme === "tropical";

  return (
    <div className={`login-container${isTropical ? " tropical" : ""}${transitionClass ? ` scene-${transitionClass}` : ""}`}>

      {/* Dark overlay that cross-fades out when going tropical */}
      <div className="theme-overlay" />

      {/* Palm scene — stays mounted during leave transition for smooth fade */}
      {sceneVisible && (
        <div className="palm-scene" aria-hidden="true">
          {/* Sky gradient layers that fade in */}
          <div className="sky-layer sky-sunset" />

          {/* Sun */}
          <div className="sun" />

          {/* Palm trees — use image if available, fall back to CSS drawing */}
          <div className="palm palm-left">
            <img
              src="/palm-left.png"
              alt=""
              className="palm-img"
              onError={(e) => { (e.target as HTMLImageElement).style.display = "none"; }}
            />
            {/* CSS fallback (shown if image fails to load / is absent) */}
            <div className="palm-css-fallback">
              <div className="trunk" />
              <div className="fronds">
                {[...Array(7)].map((_, i) => (
                  <div key={i} className={`frond frond-${i}`} />
                ))}
              </div>
            </div>
          </div>

          <div className="palm palm-right">
            <img
              src="/palm-right.png"
              alt=""
              className="palm-img"
              onError={(e) => { (e.target as HTMLImageElement).style.display = "none"; }}
            />
            <div className="palm-css-fallback">
              <div className="trunk" />
              <div className="fronds">
                {[...Array(7)].map((_, i) => (
                  <div key={i} className={`frond frond-${i}`} />
                ))}
              </div>
            </div>
          </div>

          {/* Water */}
          <div className="ocean">
            <div className="ocean-depth" />
            <div className="shimmer-layer" />
            <div className="wave-row wave-row-back">
              <div className="wavelet" /><div className="wavelet" /><div className="wavelet" />
              <div className="wavelet" /><div className="wavelet" />
            </div>
            <div className="wave-row wave-row-mid">
              <div className="wavelet" /><div className="wavelet" /><div className="wavelet" />
              <div className="wavelet" /><div className="wavelet" />
            </div>
            <div className="wave-row wave-row-front">
              <div className="wavelet" /><div className="wavelet" /><div className="wavelet" />
              <div className="wavelet" /><div className="wavelet" />
            </div>
            <div className="foam" />
          </div>
        </div>
      )}

      <img
        src="/projectlogo.png"
        alt="Logo"
        className={`login-logo${isTropical ? " tropical-logo" : ""}`}
        onClick={handleLogoClick}
        title={isTropical ? "Click to return to normal 🌙" : "Click for vibes 🌴"}
        style={{ cursor: "pointer" }}
      />
      <h1 className="title">Collector's Pair-A-Dice</h1>

      <div className="login-box">
        <h2>Login</h2>
        <form onSubmit={handleSubmit}>
          <label>Email</label>
          <input type="email" value={email} onChange={(e) => setEmail(e.target.value)} required />
          <label>Password</label>
          <input type="password" value={password} onChange={(e) => setPassword(e.target.value)} required />
          <Link to="/resetpassword" className="forgot-password">Forgot Password</Link>
          <button type="submit">Log In</button>
        </form>
        {message && (
          <p className={`login-message ${isSuccess ? "success" : "error"}`}>{message}</p>
        )}
        <p className="signup-text">
          Don't have an account? <Link to="/signup">Sign Up</Link>
        </p>
      </div>
    </div>
  );
};

export default Login;

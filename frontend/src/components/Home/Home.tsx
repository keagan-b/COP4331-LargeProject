import React, { useState } from "react";
import "./Home.css";

interface Category {
  _id: string;
  categoryName: string;
}

interface HomeProps {
  categories: Category[];
  onCategorySelect: (category: Category) => void;
  onAddCategory: (
    name: string,
    criteria: string[]
  ) => Promise<{ success: boolean; error?: string }>;
  onLogout: () => void;
}

const Home: React.FC<HomeProps> = ({
  categories,
  onCategorySelect,
  onAddCategory,
  onLogout,
}) => {
  const [showModal, setShowModal] = useState(false);
  const [newCategoryName, setNewCategoryName] = useState("");
  const [criteriaList, setCriteriaList] = useState<string[]>([]);
  const [newCriterion, setNewCriterion] = useState("");
  const [modalError, setModalError] = useState("");
  const [activeId, setActiveId] = useState<string | null>(null);

  const handleCategoryClick = (category: Category) => {
    setActiveId(category._id);
    onCategorySelect(category);
  };

  const handleAddClick = () => {
    setNewCategoryName("");
    setCriteriaList([]);
    setNewCriterion("");
    setModalError("");
    setShowModal(true);
  };

  const handleAddCriterion = () => {
    const val = newCriterion.trim();
    if (!val) return;
    setCriteriaList((prev) => [...prev, val]);
    setNewCriterion("");
  };

  const handleRemoveCriterion = (index: number) => {
    setCriteriaList((prev) => prev.filter((_, i) => i !== index));
  };

  const handleConfirm = async () => {
    const name = newCategoryName.trim();
    if (!name) {
      setModalError("Please enter a category name.");
      return;
    }
    const result = await onAddCategory(name, criteriaList);
    if (result.success) {
      setShowModal(false);
    } else {
      setModalError(result.error || "Failed to add category.");
    }
  };

  const handleNameKeyDown = (e: React.KeyboardEvent) => {
    if (e.key === "Escape") setShowModal(false);
  };

  const handleCriterionKeyDown = (e: React.KeyboardEvent) => {
    if (e.key === "Enter") handleAddCriterion();
    if (e.key === "Escape") setShowModal(false);
  };

  return (
    <div className="home-wrapper">
      {/* Header */}
      <header className="home-header">
        <h1>Collector's Pair-A-Dice</h1>
        <button className="logout-btn" onClick={onLogout}>
          Log Out
        </button>
      </header>

      <div className="home-body">
        {/* Sidebar */}
        <aside className="home-sidebar">
          {categories.map((cat) => (
            <button
              key={cat._id}
              className={`category-btn${activeId === cat._id ? " active" : ""}`}
              onClick={() => handleCategoryClick(cat)}
            >
              {cat.categoryName}
            </button>
          ))}
          <div className="sidebar-spacer" />
          <button className="add-category-btn" onClick={handleAddClick}>
            + Add Category
          </button>
        </aside>

        {/* Main */}
        <main className="home-main">
          <div className="breadcrumb">
            <span>Home</span>
          </div>
          <h2 className="home-title">Home</h2>
        </main>
      </div>

      {/* Add Category Modal */}
      {showModal && (
        <div className="modal-overlay" onClick={() => setShowModal(false)}>
          <div className="modal-box" onClick={(e) => e.stopPropagation()}>
            <h3>New Category</h3>

            {/* Category Name */}
            <div className="modal-field">
              <label className="modal-label">Category Name</label>
              <input
                type="text"
                placeholder="e.g. Trading Cards"
                value={newCategoryName}
                onChange={(e) => setNewCategoryName(e.target.value)}
                onKeyDown={handleNameKeyDown}
                autoFocus
              />
            </div>

            {/* Criteria Section */}
            <div className="modal-field">
              <label className="modal-label">Criteria</label>
              <div className="criteria-input-row">
                <input
                  type="text"
                  placeholder="e.g. Condition, Year, Grade..."
                  value={newCriterion}
                  onChange={(e) => setNewCriterion(e.target.value)}
                  onKeyDown={handleCriterionKeyDown}
                />
                <button className="add-criterion-btn" onClick={handleAddCriterion}>
                  + Add
                </button>
              </div>

              {/* Criteria Tags */}
              {criteriaList.length > 0 && (
                <div className="criteria-tags">
                  {criteriaList.map((c, i) => (
                    <span key={i} className="criteria-tag">
                      {c}
                      <button
                        className="remove-tag"
                        onClick={() => handleRemoveCriterion(i)}
                      >
                        ×
                      </button>
                    </span>
                  ))}
                </div>
              )}
            </div>

            {modalError && <p className="error-msg">{modalError}</p>}

            <div className="modal-actions">
              <button className="modal-cancel" onClick={() => setShowModal(false)}>
                Cancel
              </button>
              <button className="modal-confirm" onClick={handleConfirm}>
                Create
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
};

export default Home;

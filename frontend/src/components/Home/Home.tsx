import React, { useState, useEffect, useRef } from "react";
import "./Home.css";

interface Category {
  _id: string;
  categoryName: string;
}

interface HomeProps {
  categories: Category[];
  onCategorySelect: (category: Category) => void;
  onAddCategory: (name: string, criteria: string[]) => Promise<{ success: boolean; error?: string }>;
  onEditCategory: (categoryId: string, name: string, criteria: string[]) => Promise<{ success: boolean; error?: string }>;
  onDeleteCategory: (categoryId: string) => Promise<{ success: boolean; error?: string }>;
  getCategoryCriteria: (categoryId: string) => Promise<string[]>;
  onLogout: () => void;
}

const Home: React.FC<HomeProps> = ({
  categories,
  onCategorySelect,
  onAddCategory,
  onEditCategory,
  onDeleteCategory,
  getCategoryCriteria,
  onLogout,
}) => {
  const [activeId, setActiveId] = useState<string | null>(null);
  const [openMenuId, setOpenMenuId] = useState<string | null>(null);
  const menuRef = useRef<HTMLDivElement>(null);

  // Add category modal
  const [showAddModal, setShowAddModal] = useState(false);
  const [newCategoryName, setNewCategoryName] = useState("");
  const [criteriaList, setCriteriaList] = useState<string[]>([]);
  const [newCriterion, setNewCriterion] = useState("");
  const [addModalError, setAddModalError] = useState("");

  // Edit category modal
  const [showEditModal, setShowEditModal] = useState(false);
  const [editingCategory, setEditingCategory] = useState<Category | null>(null);
  const [editCategoryName, setEditCategoryName] = useState("");
  const [editCriteriaList, setEditCriteriaList] = useState<string[]>([]);
  const [editNewCriterion, setEditNewCriterion] = useState("");
  const [editModalError, setEditModalError] = useState("");

  // Delete category modal
  const [showDeleteModal, setShowDeleteModal] = useState(false);
  const [deletingCategory, setDeletingCategory] = useState<Category | null>(null);
  const [deleteModalError, setDeleteModalError] = useState("");

  // Close menu on outside click
  useEffect(() => {
    const handler = (e: MouseEvent) => {
      if (menuRef.current && !menuRef.current.contains(e.target as Node)) {
        setOpenMenuId(null);
      }
    };
    document.addEventListener("mousedown", handler);
    return () => document.removeEventListener("mousedown", handler);
  }, []);

  const handleCategoryClick = (category: Category) => {
    setActiveId(category._id);
    onCategorySelect(category);
  };

  // Add modal handlers
  const handleAddClick = () => {
    setNewCategoryName("");
    setCriteriaList([]);
    setNewCriterion("");
    setAddModalError("");
    setShowAddModal(true);
  };

  const handleAddCriterion = () => {
    const val = newCriterion.trim();
    if (!val) return;
    setCriteriaList((prev) => [...prev, val]);
    setNewCriterion("");
  };

  const handleAddConfirm = async () => {
    const name = newCategoryName.trim();
    if (!name) { setAddModalError("Please enter a category name."); return; }
    const result = await onAddCategory(name, criteriaList);
    if (result.success) setShowAddModal(false);
    else setAddModalError(result.error || "Failed to add category.");
  };

  // Edit modal handlers
  const handleEditClick = async (cat: Category) => {
    setOpenMenuId(null);
    setEditingCategory(cat);
    setEditCategoryName(cat.categoryName);
    setEditNewCriterion("");
    setEditModalError("");
    // Load existing criteria
    const existing = await getCategoryCriteria(cat._id);
    setEditCriteriaList(existing);
    setShowEditModal(true);
  };

  const handleEditAddCriterion = () => {
    const val = editNewCriterion.trim();
    if (!val) return;
    setEditCriteriaList((prev) => [...prev, val]);
    setEditNewCriterion("");
  };

  const handleEditConfirm = async () => {
    if (!editingCategory) return;
    const name = editCategoryName.trim();
    if (!name) { setEditModalError("Please enter a category name."); return; }
    const result = await onEditCategory(editingCategory._id, name, editCriteriaList);
    if (result.success) setShowEditModal(false);
    else setEditModalError(result.error || "Failed to update category.");
  };

  // Delete modal handlers
  const handleDeleteClick = (cat: Category) => {
    setOpenMenuId(null);
    setDeletingCategory(cat);
    setDeleteModalError("");
    setShowDeleteModal(true);
  };

  const handleDeleteConfirm = async () => {
    if (!deletingCategory) return;
    const result = await onDeleteCategory(deletingCategory._id);
    if (result.success) setShowDeleteModal(false);
    else setDeleteModalError(result.error || "Failed to delete category.");
  };

  return (
    <div className="home-wrapper">
      {/* Header */}
      <header className="home-header">
        <h1>Collector's Pair-A-Dice</h1>
        <button className="logout-btn" onClick={onLogout}>Log Out</button>
      </header>

      <div className="home-body">
        {/* Sidebar */}
        <aside className="home-sidebar">
          <div className="sidebar-scroll" ref={menuRef}>
            {categories.map((cat) => (
              <div key={cat._id} className="category-row">
                <button
                  className={`category-btn${activeId === cat._id ? " active" : ""}`}
                  onClick={() => handleCategoryClick(cat)}
                >
                  {cat.categoryName}
                </button>

                {/* Three-dot menu */}
                <div className="col-menu-wrapper">
                  <button
                    className="col-menu-btn"
                    onClick={(e) => {
                      e.stopPropagation();
                      setOpenMenuId(openMenuId === cat._id ? null : cat._id);
                    }}
                  >
                    ⋮
                  </button>
                  {openMenuId === cat._id && (
                    <div className="col-menu-popover">
                      <button className="col-menu-option" onClick={() => handleEditClick(cat)}>
                        ✎ Edit
                      </button>
                      <button className="col-menu-option col-menu-option-delete" onClick={() => handleDeleteClick(cat)}>
                        ✕ Delete
                      </button>
                    </div>
                  )}
                </div>
              </div>
            ))}
          </div>

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
      {showAddModal && (
        <div className="modal-overlay" onClick={() => setShowAddModal(false)}>
          <div className="modal-box" onClick={(e) => e.stopPropagation()}>
            <h3>New Category</h3>
            <div className="modal-field">
              <label className="modal-label">Category Name</label>
              <input
                type="text"
                placeholder="e.g. Trading Cards"
                value={newCategoryName}
                onChange={(e) => setNewCategoryName(e.target.value)}
                onKeyDown={(e) => { if (e.key === "Escape") setShowAddModal(false); }}
                autoFocus
              />
            </div>
            <div className="modal-field">
              <label className="modal-label">Criteria</label>
              <div className="criteria-input-row">
                <input
                  type="text"
                  placeholder="e.g. Condition, Year..."
                  value={newCriterion}
                  onChange={(e) => setNewCriterion(e.target.value)}
                  onKeyDown={(e) => { if (e.key === "Enter") handleAddCriterion(); }}
                />
                <button className="add-criterion-btn" onClick={handleAddCriterion}>+ Add</button>
              </div>
              {criteriaList.length > 0 && (
                <div className="criteria-tags">
                  {criteriaList.map((c, i) => (
                    <span key={i} className="criteria-tag">
                      {c}
                      <button className="remove-tag" onClick={() => setCriteriaList((prev) => prev.filter((_, j) => j !== i))}>×</button>
                    </span>
                  ))}
                </div>
              )}
            </div>
            {addModalError && <p className="error-msg">{addModalError}</p>}
            <div className="modal-actions">
              <button className="modal-cancel" onClick={() => setShowAddModal(false)}>Cancel</button>
              <button className="modal-confirm" onClick={handleAddConfirm}>Create</button>
            </div>
          </div>
        </div>
      )}

      {/* Edit Category Modal */}
      {showEditModal && (
        <div className="modal-overlay" onClick={() => setShowEditModal(false)}>
          <div className="modal-box" onClick={(e) => e.stopPropagation()}>
            <h3>Edit Category</h3>
            <div className="modal-field">
              <label className="modal-label">Category Name</label>
              <input
                type="text"
                value={editCategoryName}
                onChange={(e) => setEditCategoryName(e.target.value)}
                onKeyDown={(e) => { if (e.key === "Enter") handleEditConfirm(); }}
                autoFocus
              />
            </div>
            <div className="modal-field">
              <label className="modal-label">Criteria</label>
              <div className="criteria-input-row">
                <input
                  type="text"
                  placeholder="Add new criterion..."
                  value={editNewCriterion}
                  onChange={(e) => setEditNewCriterion(e.target.value)}
                  onKeyDown={(e) => { if (e.key === "Enter") handleEditAddCriterion(); }}
                />
                <button className="add-criterion-btn" onClick={handleEditAddCriterion}>+ Add</button>
              </div>
              {editCriteriaList.length > 0 && (
                <div className="criteria-tags">
                  {editCriteriaList.map((c, i) => (
                    <span key={i} className="criteria-tag">
                      {c}
                      <button className="remove-tag" onClick={() => setEditCriteriaList((prev) => prev.filter((_, j) => j !== i))}>×</button>
                    </span>
                  ))}
                </div>
              )}
            </div>
            {editModalError && <p className="error-msg">{editModalError}</p>}
            <div className="modal-actions">
              <button className="modal-cancel" onClick={() => setShowEditModal(false)}>Cancel</button>
              <button className="modal-confirm" onClick={handleEditConfirm}>Save</button>
            </div>
          </div>
        </div>
      )}

      {/* Delete Category Modal */}
      {showDeleteModal && (
        <div className="modal-overlay" onClick={() => setShowDeleteModal(false)}>
          <div className="modal-box" onClick={(e) => e.stopPropagation()}>
            <h3>Delete Category</h3>
            <p style={{ color: "gray", fontSize: "0.9rem" }}>
              Are you sure you want to delete <span style={{ color: "white" }}>{deletingCategory?.categoryName}</span>? This cannot be undone.
            </p>
            {deleteModalError && <p className="error-msg">{deleteModalError}</p>}
            <div className="modal-actions">
              <button className="modal-cancel" onClick={() => setShowDeleteModal(false)}>Cancel</button>
              <button className="modal-delete" onClick={handleDeleteConfirm}>Delete</button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
};

export default Home;

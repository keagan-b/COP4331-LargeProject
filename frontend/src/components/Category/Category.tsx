import React, { useState, useRef, useEffect } from "react";
import "./Category.css";

interface Collection {
  _id: string;
  collectionName: string;
}

interface Criteria {
  _id: string;
  criteriaName: string;
}

interface Item {
  _id: string;
  itemName: string;
  categoryId: string;
  criteriaValues?: Record<string, string>;
}

interface CategoryProps {
  activeCollectionId?: string | null;
  categoryName: string;
  categoryId: string;
  collections: Collection[];
  criteria: Criteria[];
  items: Item[];
  onCollectionSelect: (collection: Collection) => void;
  onAddCollection: (name: string) => Promise<{ success: boolean; error?: string }>;
  onEditCollection: (collectionId: string, newName: string) => Promise<{ success: boolean; error?: string }>;
  onDeleteCollection: (collectionId: string) => Promise<{ success: boolean; error?: string }>;
  onAddItem: (itemName: string, criteriaValues: Record<string, string>) => Promise<{ success: boolean; error?: string }>;
  onEditItem: (itemId: string, itemName: string, criteriaValues: Record<string, string>) => Promise<{ success: boolean; error?: string }>;
  onDeleteItem: (itemId: string) => Promise<{ success: boolean; error?: string }>;
  onNavigateHome: () => void;
  onLogout: () => void;
}

const Category: React.FC<CategoryProps> = ({
  activeCollectionId,
  categoryName,
  collections,
  criteria,
  items,
  onCollectionSelect,
  onAddCollection,
  onEditCollection,
  onDeleteCollection,
  onAddItem,
  onEditItem,
  onDeleteItem,
  onNavigateHome,
  onLogout,
}) => {
  const [activeId, setActiveId] = useState<string | null>(activeCollectionId ?? null);

  useEffect(() => {
    setActiveId(activeCollectionId ?? null);
  }, [activeCollectionId]);

  // Add collection modal
  const [showCollectionModal, setShowCollectionModal] = useState(false);
  const [newCollectionName, setNewCollectionName] = useState("");
  const [collectionModalError, setCollectionModalError] = useState("");

  // Edit collection modal
  const [showEditCollectionModal, setShowEditCollectionModal] = useState(false);
  const [editingCollection, setEditingCollection] = useState<Collection | null>(null);
  const [editCollectionName, setEditCollectionName] = useState("");
  const [editCollectionError, setEditCollectionError] = useState("");

  // Delete collection modal
  const [showDeleteCollectionModal, setShowDeleteCollectionModal] = useState(false);
  const [deletingCollection, setDeletingCollection] = useState<Collection | null>(null);
  const [deleteCollectionError, setDeleteCollectionError] = useState("");

  // Search & filter
  const [searchQuery, setSearchQuery] = useState("");
  const [filterCriteria, setFilterCriteria] = useState("");
  const [dropdownOpen, setDropdownOpen] = useState(false);
  const dropdownRef = useRef<HTMLDivElement>(null);

  // Add item modal
  const [showItemModal, setShowItemModal] = useState(false);
  const [newItemName, setNewItemName] = useState("");
  const [criteriaValues, setCriteriaValues] = useState<Record<string, string>>({});
  const [itemModalError, setItemModalError] = useState("");

  // View/Edit/Delete item modal
  const [selectedItem, setSelectedItem] = useState<Item | null>(null);
  const [isEditing, setIsEditing] = useState(false);
  const [editItemName, setEditItemName] = useState("");
  const [editCriteriaValues, setEditCriteriaValues] = useState<Record<string, string>>({});
  const [itemViewError, setItemViewError] = useState("");
  const [showDeleteItemConfirm, setShowDeleteItemConfirm] = useState(false);

  // Close filter dropdown on outside click
  useEffect(() => {
    const handler = (e: MouseEvent) => {
      if (dropdownRef.current && !dropdownRef.current.contains(e.target as Node)) {
        setDropdownOpen(false);
      }
    };
    document.addEventListener("mousedown", handler);
    return () => document.removeEventListener("mousedown", handler);
  }, []);

  // Filter items
  const filteredItems = items.filter((item) => {
    if (!searchQuery) return true;
    const query = searchQuery.toLowerCase();
    if (filterCriteria) {
      return (item.criteriaValues?.[filterCriteria] ?? "").toLowerCase().includes(query);
    }
    const nameMatch = item.itemName.toLowerCase().includes(query);
    const criteriaMatch = Object.values(item.criteriaValues ?? {}).some((val) =>
      val.toLowerCase().includes(query)
    );
    return nameMatch || criteriaMatch;
  });

  // Open item view modal
  const handleItemClick = (item: Item) => {
    setSelectedItem(item);
    setIsEditing(false);
    setEditItemName(item.itemName);
    setEditCriteriaValues({ ...item.criteriaValues });
    setItemViewError("");
    setShowDeleteItemConfirm(false);
  };

  const handleCloseItemModal = () => {
    setSelectedItem(null);
    setIsEditing(false);
    setShowDeleteItemConfirm(false);
    setItemViewError("");
  };

  const handleSaveItem = async () => {
    if (!selectedItem) return;
    const name = editItemName.trim();
    if (!name) { setItemViewError("Item name cannot be empty."); return; }
    const result = await onEditItem(selectedItem._id, name, editCriteriaValues);
    if (result.success) {
      setIsEditing(false);
      setItemViewError("");
    } else {
      setItemViewError(result.error || "Failed to save changes.");
    }
  };

  const handleDeleteItem = async () => {
    if (!selectedItem) return;
    const result = await onDeleteItem(selectedItem._id);
    if (result.success) handleCloseItemModal();
    else setItemViewError(result.error || "Failed to delete item.");
  };

  // Add collection handlers
  const handleAddCollectionClick = () => {
    setNewCollectionName("");
    setCollectionModalError("");
    setShowCollectionModal(true);
  };

  const handleCollectionConfirm = async () => {
    const name = newCollectionName.trim();
    if (!name) { setCollectionModalError("Please enter a collection name."); return; }
    const result = await onAddCollection(name);
    if (result.success) setShowCollectionModal(false);
    else setCollectionModalError(result.error || "Failed to add collection.");
  };

  // Edit collection handlers
  const handleEditCollectionClick = (e: React.MouseEvent, col: Collection) => {
    e.stopPropagation();
    setEditingCollection(col);
    setEditCollectionName(col.collectionName);
    setEditCollectionError("");
    setShowEditCollectionModal(true);
  };

  const handleEditCollectionConfirm = async () => {
    if (!editingCollection) return;
    const name = editCollectionName.trim();
    if (!name) { setEditCollectionError("Please enter a collection name."); return; }
    const result = await onEditCollection(editingCollection._id, name);
    if (result.success) setShowEditCollectionModal(false);
    else setEditCollectionError(result.error || "Failed to update collection.");
  };

  // Delete collection handlers
  const handleDeleteCollectionClick = (e: React.MouseEvent, col: Collection) => {
    e.stopPropagation();
    setDeletingCollection(col);
    setDeleteCollectionError("");
    setShowDeleteCollectionModal(true);
  };

  const handleDeleteCollectionConfirm = async () => {
    if (!deletingCollection) return;
    const result = await onDeleteCollection(deletingCollection._id);
    if (result.success) setShowDeleteCollectionModal(false);
    else setDeleteCollectionError(result.error || "Failed to delete collection.");
  };

  // Add item handlers
  const handleAddItemClick = () => {
    setNewItemName("");
    setCriteriaValues({});
    setItemModalError("");
    setShowItemModal(true);
  };

  const handleItemConfirm = async () => {
    const name = newItemName.trim();
    if (!name) { setItemModalError("Please enter an item name."); return; }
    const result = await onAddItem(name, criteriaValues);
    if (result.success) setShowItemModal(false);
    else setItemModalError(result.error || "Failed to add item.");
  };

  return (
    <div className="category-wrapper">
      {/* Header */}
      <header className="category-header">
        <h1>Collector's Pair-A-Dice</h1>
        <button className="logout-btn" onClick={onLogout}>Log Out</button>
      </header>

      <div className="category-body">
        {/* Sidebar */}
        <aside className="category-sidebar">
          <div className="sidebar-scroll">
            {collections.map((col) => (
              <div key={col._id} className="collection-row">
                <button
                  className={`collection-btn${activeId === col._id ? " active" : ""}`}
                  onClick={() => { setActiveId(col._id); onCollectionSelect(col); }}
                >
                  {col.collectionName}
                </button>
                <button className="collection-edit-btn" title="Edit" onClick={(e) => handleEditCollectionClick(e, col)}>✎</button>
                <button className="collection-delete-btn" title="Delete" onClick={(e) => handleDeleteCollectionClick(e, col)}>✕</button>
              </div>
            ))}
          </div>
          <button className="add-collection-btn" onClick={handleAddCollectionClick}>
            + Add Collection
          </button>
        </aside>

        {/* Main */}
        <main className="category-main">
          <div className="breadcrumb">
            <span onClick={onNavigateHome}>Home</span>
            <span className="breadcrumb-sep">&gt;</span>
            <span className="breadcrumb-current">{categoryName}</span>
            <span className="breadcrumb-sep">&gt;</span>
          </div>

          <div className="category-top">
            <h2 className="category-title">{categoryName}:</h2>
            <div className="search-row">
              <div className="filter-dropdown-wrapper" ref={dropdownRef}>
                <button className="filter-btn" onClick={() => setDropdownOpen((o) => !o)}>
                  {filterCriteria || "Filter"}
                  <span className={`arrow${dropdownOpen ? " open" : ""}`}>▼</span>
                </button>
                {dropdownOpen && (
                  <div className="filter-dropdown">
                    <div
                      className={`filter-option${filterCriteria === "" ? " selected" : ""}`}
                      onClick={() => { setFilterCriteria(""); setDropdownOpen(false); }}
                    >
                      All
                    </div>
                    {criteria.map((c) => (
                      <div
                        key={c._id}
                        className={`filter-option${filterCriteria === c.criteriaName ? " selected" : ""}`}
                        onClick={() => { setFilterCriteria(c.criteriaName); setDropdownOpen(false); }}
                      >
                        {c.criteriaName}
                      </div>
                    ))}
                  </div>
                )}
              </div>
              <input
                className="search-input"
                type="text"
                placeholder="Search..."
                value={searchQuery}
                onChange={(e) => setSearchQuery(e.target.value)}
              />
            </div>
          </div>

          <div className="items-grid">
            <div className="item-card-add" onClick={handleAddItemClick}>
              <span className="plus-icon">+</span>
            </div>
            {filteredItems.map((item) => (
              <div key={item._id} className="item-card" onClick={() => handleItemClick(item)}>
                <div className="item-card-body">
                  
                </div>
                <div className="item-card-footer">{item.itemName}</div>
              </div>
            ))}
          </div>
        </main>
      </div>

      {selectedItem && (
        <div className="modal-overlay" onClick={handleCloseItemModal}>
          <div className="modal-box item-view-box" onClick={(e) => e.stopPropagation()}>

            {/* Item name */}
            <div className="modal-field">
              <label className="modal-label">Item Name</label>
              {isEditing ? (
                <input
                  type="text"
                  value={editItemName}
                  onChange={(e) => setEditItemName(e.target.value)}
                  autoFocus
                />
              ) : (
                <p className="item-view-value item-view-name">{selectedItem.itemName}</p>
              )}
            </div>

            {/* Criteria */}
            {criteria.length > 0 && (
              <>
                <hr className="modal-divider" />
                {criteria.map((c) => (
                  <div className="modal-field" key={c._id}>
                    <label className="modal-label">{c.criteriaName}</label>
                    {isEditing ? (
                      <input
                        type="text"
                        value={editCriteriaValues[c.criteriaName] || ""}
                        onChange={(e) =>
                          setEditCriteriaValues((prev) => ({ ...prev, [c.criteriaName]: e.target.value }))
                        }
                      />
                    ) : (
                      <p className="item-view-value">
                        {selectedItem.criteriaValues?.[c.criteriaName] || "—"}
                      </p>
                    )}
                  </div>
                ))}
              </>
            )}

            {itemViewError && <p className="error-msg">{itemViewError}</p>}

            {/* Delete confirmation inline */}
            {showDeleteItemConfirm && (
              <p style={{ color: "var(--text-secondary)", fontSize: "0.88rem", textAlign: "center" }}>
                Are you sure you want to delete <strong style={{ color: "var(--text-primary)" }}>{selectedItem.itemName}</strong>?
              </p>
            )}

            {/* Actions */}
            <div className="modal-actions">
              {!isEditing && !showDeleteItemConfirm && (
                <>
                  <button className="modal-cancel" onClick={handleCloseItemModal}>Close</button>
                  <button className="modal-edit" onClick={() => setIsEditing(true)}>Edit</button>
                  <button className="modal-delete" onClick={() => setShowDeleteItemConfirm(true)}>Delete</button>
                </>
              )}
              {isEditing && (
                <>
                  <button className="modal-cancel" onClick={() => { setIsEditing(false); setItemViewError(""); }}>Cancel</button>
                  <button className="modal-confirm" onClick={handleSaveItem}>Save</button>
                </>
              )}
              {showDeleteItemConfirm && (
                <>
                  <button className="modal-cancel" onClick={() => setShowDeleteItemConfirm(false)}>Cancel</button>
                  <button className="modal-delete" onClick={handleDeleteItem}>Confirm Delete</button>
                </>
              )}
            </div>
          </div>
        </div>
      )}

      {/* Add Collection Modal */}
      {showCollectionModal && (
        <div className="modal-overlay" onClick={() => setShowCollectionModal(false)}>
          <div className="modal-box" onClick={(e) => e.stopPropagation()}>
            <h3>New Collection</h3>
            <input
              type="text"
              placeholder="Collection name..."
              value={newCollectionName}
              onChange={(e) => setNewCollectionName(e.target.value)}
              onKeyDown={(e) => { if (e.key === "Enter") handleCollectionConfirm(); }}
              autoFocus
            />
            {collectionModalError && <p className="error-msg">{collectionModalError}</p>}
            <div className="modal-actions">
              <button className="modal-cancel" onClick={() => setShowCollectionModal(false)}>Cancel</button>
              <button className="modal-confirm" onClick={handleCollectionConfirm}>Create</button>
            </div>
          </div>
        </div>
      )}

      {/* Edit Collection Modal */}
      {showEditCollectionModal && (
        <div className="modal-overlay" onClick={() => setShowEditCollectionModal(false)}>
          <div className="modal-box" onClick={(e) => e.stopPropagation()}>
            <h3>Edit Collection</h3>
            <input
              type="text"
              value={editCollectionName}
              onChange={(e) => setEditCollectionName(e.target.value)}
              onKeyDown={(e) => { if (e.key === "Enter") handleEditCollectionConfirm(); }}
              autoFocus
            />
            {editCollectionError && <p className="error-msg">{editCollectionError}</p>}
            <div className="modal-actions">
              <button className="modal-cancel" onClick={() => setShowEditCollectionModal(false)}>Cancel</button>
              <button className="modal-confirm" onClick={handleEditCollectionConfirm}>Save</button>
            </div>
          </div>
        </div>
      )}

      {/* Delete Collection Modal */}
      {showDeleteCollectionModal && (
        <div className="modal-overlay" onClick={() => setShowDeleteCollectionModal(false)}>
          <div className="modal-box" onClick={(e) => e.stopPropagation()}>
            <h3>Delete Collection</h3>
            <p style={{ color: "var(--text-secondary)", fontSize: "0.9rem" }}>
              Are you sure you want to delete <strong style={{ color: "var(--text-primary)" }}>{deletingCollection?.collectionName}</strong>? This cannot be undone.
            </p>
            {deleteCollectionError && <p className="error-msg">{deleteCollectionError}</p>}
            <div className="modal-actions">
              <button className="modal-cancel" onClick={() => setShowDeleteCollectionModal(false)}>Cancel</button>
              <button className="modal-delete" onClick={handleDeleteCollectionConfirm}>Delete</button>
            </div>
          </div>
        </div>
      )}

      {/* Add Item Modal */}
      {showItemModal && (
        <div className="modal-overlay" onClick={() => setShowItemModal(false)}>
          <div className="modal-box" onClick={(e) => e.stopPropagation()}>
            <h3>New Item</h3>
            <div className="modal-field">
              <label className="modal-label">Item Name</label>
              <input
                type="text"
                placeholder="Name"
                value={newItemName}
                onChange={(e) => setNewItemName(e.target.value)}
                autoFocus
              />
            </div>
            {criteria.length > 0 && (
              <>
                <hr className="modal-divider" />
                {criteria.map((c) => (
                  <div className="modal-field" key={c._id}>
                    <label className="modal-label">{c.criteriaName}</label>
                    <input
                      type="text"
                      placeholder={`${c.criteriaName}`}
                      value={criteriaValues[c.criteriaName] || ""}
                      onChange={(e) =>
                        setCriteriaValues((prev) => ({ ...prev, [c.criteriaName]: e.target.value }))
                      }
                    />
                  </div>
                ))}
              </>
            )}
            {itemModalError && <p className="error-msg">{itemModalError}</p>}
            <div className="modal-actions">
              <button className="modal-cancel" onClick={() => setShowItemModal(false)}>Cancel</button>
              <button className="modal-confirm" onClick={handleItemConfirm}>Add Item</button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
};

export default Category;
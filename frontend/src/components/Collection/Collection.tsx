import React, { useState, useRef, useEffect } from "react";
import "./Collection.css";

interface SiblingCollection {
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
  collectionId?: string;
  criteriaValues?: Record<string, string>;
}

interface CollectionProps {
  categoryName: string;
  collectionName: string;
  siblingCollections: SiblingCollection[];
  criteria: Criteria[];
  items: Item[];
  onSiblingSelect: (collection: SiblingCollection) => void;
  onAddItem: (
    itemName: string,
    criteriaValues: Record<string, string>
  ) => Promise<{ success: boolean; error?: string }>;
  onNavigateHome: () => void;
  onNavigateCategory: () => void;
  onLogout: () => void;
}

const Collection: React.FC<CollectionProps> = ({
  categoryName,
  collectionName,
  siblingCollections,
  criteria,
  items,
  onSiblingSelect,
  onAddItem,
  onNavigateHome,
  onNavigateCategory,
  onLogout,
}) => {
  // Search & filter
  const [searchQuery, setSearchQuery] = useState("");
  const [filterCriteria, setFilterCriteria] = useState("");
  const [dropdownOpen, setDropdownOpen] = useState(false);
  const dropdownRef = useRef<HTMLDivElement>(null);
  const [activeId, setActiveId] = useState<string | null>(null);

  // Add item modal
  const [showItemModal, setShowItemModal] = useState(false);
  const [newItemName, setNewItemName] = useState("");
  const [criteriaValues, setCriteriaValues] = useState<Record<string, string>>({});
  const [itemModalError, setItemModalError] = useState("");

  // Close dropdown on outside click
  useEffect(() => {
    const handler = (e: MouseEvent) => {
      if (dropdownRef.current && !dropdownRef.current.contains(e.target as Node)) {
        setDropdownOpen(false);
      }
    };
    document.addEventListener("mousedown", handler);
    return () => document.removeEventListener("mousedown", handler);
  }, []);

  // Filter items — only shows items belonging to this collection (already filtered by page)
  const filteredItems = items.filter((item) => {
    if (!searchQuery) return true;
    const query = searchQuery.toLowerCase();
    if (filterCriteria) {
      return (item.criteriaValues?.[filterCriteria] ?? "").toLowerCase().includes(query);
    }
    const nameMatch = item.itemName.toLowerCase().includes(query);
    const criteriaMatch = Object.values(item.criteriaValues ?? {}).some((v) =>
      v.toLowerCase().includes(query)
    );
    return nameMatch || criteriaMatch;
  });

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
    <div className="collection-wrapper">
      {/* Header */}
      <header className="collection-header">
        <h1>Collector's Pair-A-Dice</h1>
        <button className="logout-btn" onClick={onLogout}>Log Out</button>
      </header>

      <div className="collection-body">
        {/* Sidebar — shows sibling collections in the same category */}
        <aside className="collection-sidebar">
          {siblingCollections.map((col) => (
            <button
              key={col._id}
              className={`sibling-collection-btn${activeId === col._id ? " active" : ""}`}
              onClick={() => { setActiveId(col._id); onSiblingSelect(col); }}
            >
              {col.collectionName}
            </button>
          ))}
          <div className="sidebar-spacer" />
        </aside>

        {/* Main */}
        <main className="collection-main">
          {/* Breadcrumb: Home > Category > Collection */}
          <div className="breadcrumb">
            <span onClick={onNavigateHome}>Home</span>
            <span className="breadcrumb-sep">&gt;</span>
            <span onClick={onNavigateCategory}>{categoryName}</span>
            <span className="breadcrumb-sep">&gt;</span>
            <span className="breadcrumb-current">{collectionName}</span>
            <span className="breadcrumb-sep">&gt;</span>
          </div>

          <h2 className="collection-title">{collectionName}:</h2>

          {/* Search Row */}
          <div className="search-row">
            <div className="filter-dropdown-wrapper" ref={dropdownRef}>
              <button
                className="filter-btn"
                onClick={() => setDropdownOpen((o) => !o)}
              >
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

          {/* Items Grid */}
          <div className="items-grid">
            <div className="item-card-add" onClick={handleAddItemClick}>
              <span className="plus-icon">+</span>
            </div>
            {filteredItems.map((item) => (
              <div key={item._id} className="item-card">
                <div className="item-card-body">
                  {criteria.length > 0 && item.criteriaValues && (
                    <div style={{ fontSize: "0.75rem", color: "var(--text-secondary)", textAlign: "left", width: "100%" }}>
                      {criteria.map((c) => (
                        <div key={c._id}>
                          <span style={{ color: "var(--accent)" }}>{c.criteriaName}:</span>{" "}
                          {item.criteriaValues?.[c.criteriaName] || "—"}
                        </div>
                      ))}
                    </div>
                  )}
                </div>
                <div className="item-card-footer">{item.itemName}</div>
              </div>
            ))}
          </div>
        </main>
      </div>

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
                onKeyDown={(e) => { if (e.key === "Enter") handleItemConfirm(); }}
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
                      placeholder={`Enter ${c.criteriaName}...`}
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

export default Collection;

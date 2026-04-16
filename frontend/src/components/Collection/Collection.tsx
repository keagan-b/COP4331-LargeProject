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
    imageUrl?: string;
}

interface CollectionProps {
    categoryName: string;
    collectionName: string;
    siblingCollections: SiblingCollection[];
    criteria: Criteria[];
    items: Item[];
    onSiblingSelect: (collection: SiblingCollection) => void;
    onEditCollection: (collectionId: string, newName: string) => Promise<{ success: boolean; error?: string }>;
    onDeleteCollection: (collectionId: string) => Promise<{ success: boolean; error?: string }>;
    onAddItem: (itemName: string, criteriaValues: Record<string, string>, imageUrl?: string) => Promise<{ success: boolean; error?: string }>;
    onEditItem: (itemId: string, itemName: string, criteriaValues: Record<string, string>, imageUrl?: string) => Promise<{ success: boolean; error?: string }>;
    onDeleteItem: (itemId: string) => Promise<{ success: boolean; error?: string }>;
    onUploadImage: (file: File) => Promise<{ url: string; error?: string }>;
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
    onEditCollection,
    onDeleteCollection,
    onAddItem,
    onEditItem,
    onDeleteItem,
    onUploadImage,
    onNavigateHome,
    onNavigateCategory,
    onLogout,
}) => {
    const [activeId, setActiveId] = useState<string | null>(null);
    const [openMenuId, setOpenMenuId] = useState<string | null>(null);
    const menuRef = useRef<HTMLDivElement>(null);

    // Edit/Delete collection modals
    const [showEditCollectionModal, setShowEditCollectionModal] = useState(false);
    const [editingCollection, setEditingCollection] = useState<SiblingCollection | null>(null);
    const [editCollectionName, setEditCollectionName] = useState("");
    const [editCollectionError, setEditCollectionError] = useState("");
    const [showDeleteCollectionModal, setShowDeleteCollectionModal] = useState(false);
    const [deletingCollection, setDeletingCollection] = useState<SiblingCollection | null>(null);
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
    const [newItemImageUrl, setNewItemImageUrl] = useState<string>("");
    const [uploadingNew, setUploadingNew] = useState(false);
    const newFileRef = useRef<HTMLInputElement>(null);

    // View/Edit/Delete item modal
    const [selectedItem, setSelectedItem] = useState<Item | null>(null);
    const [isEditing, setIsEditing] = useState(false);
    const [editItemName, setEditItemName] = useState("");
    const [editCriteriaValues, setEditCriteriaValues] = useState<Record<string, string>>({});
    const [editImageUrl, setEditImageUrl] = useState<string>("");
    const [uploadingEdit, setUploadingEdit] = useState(false);
    const editFileRef = useRef<HTMLInputElement>(null);
    const [itemViewError, setItemViewError] = useState("");
    const [showDeleteItemConfirm, setShowDeleteItemConfirm] = useState(false);

    useEffect(() => {
        const handler = (e: MouseEvent) => {
            if (dropdownRef.current && !dropdownRef.current.contains(e.target as Node)) setDropdownOpen(false);
            if (menuRef.current && !menuRef.current.contains(e.target as Node)) setOpenMenuId(null);
        };
        document.addEventListener("mousedown", handler);
        return () => document.removeEventListener("mousedown", handler);
    }, []);

    const filteredItems = items.filter((item) => {
        if (!searchQuery) return true;
        const query = searchQuery.toLowerCase();
        if (filterCriteria) return (item.criteriaValues?.[filterCriteria] ?? "").toLowerCase().includes(query);
        const nameMatch = item.itemName.toLowerCase().includes(query);
        const criteriaMatch = Object.values(item.criteriaValues ?? {}).some((val) => val.toLowerCase().includes(query));
        return nameMatch || criteriaMatch;
    });

    const handleNewImageChange = async (e: React.ChangeEvent<HTMLInputElement>) => {
        const file = e.target.files?.[0];
        if (!file) return;
        setUploadingNew(true);
        const result = await onUploadImage(file);
        if (result.url) setNewItemImageUrl(result.url);
        setUploadingNew(false);
    };

    const handleEditImageChange = async (e: React.ChangeEvent<HTMLInputElement>) => {
        const file = e.target.files?.[0];
        if (!file) return;
        setUploadingEdit(true);
        const result = await onUploadImage(file);
        if (result.url) setEditImageUrl(result.url);
        setUploadingEdit(false);
    };

    const handleItemClick = (item: Item) => {
        setSelectedItem(item);
        setIsEditing(false);
        setEditItemName(item.itemName);
        setEditCriteriaValues({ ...item.criteriaValues });
        setEditImageUrl(item.imageUrl || "");
        setItemViewError("");
        setShowDeleteItemConfirm(false);
    };

    const handleCloseItemModal = () => { setSelectedItem(null); setIsEditing(false); setShowDeleteItemConfirm(false); setItemViewError(""); };

    // Save Item
    const handleSaveItem = async () => {
        if (!selectedItem) return;
        const name = editItemName.trim();
        if (!name) { setItemViewError("Item name cannot be empty."); return; }
        const result = await onEditItem(selectedItem._id, name, editCriteriaValues, editImageUrl);
        if (result.success) {
            setSelectedItem({ ...selectedItem, itemName: name, criteriaValues: editCriteriaValues, imageUrl: editImageUrl });
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

    const handleEditCollectionClick = (col: SiblingCollection) => { setOpenMenuId(null); setEditingCollection(col); setEditCollectionName(col.collectionName); setEditCollectionError(""); setShowEditCollectionModal(true); };
    const handleEditCollectionConfirm = async () => {
        if (!editingCollection) return;
        const name = editCollectionName.trim();
        if (!name) { setEditCollectionError("Please enter a name."); return; }
        const result = await onEditCollection(editingCollection._id, name);
        if (result.success) setShowEditCollectionModal(false);
        else setEditCollectionError(result.error || "Failed to update.");
    };
    const handleDeleteCollectionClick = (col: SiblingCollection) => { setOpenMenuId(null); setDeletingCollection(col); setDeleteCollectionError(""); setShowDeleteCollectionModal(true); };
    const handleDeleteCollectionConfirm = async () => {
        if (!deletingCollection) return;
        const result = await onDeleteCollection(deletingCollection._id);
        if (result.success) setShowDeleteCollectionModal(false);
        else setDeleteCollectionError(result.error || "Failed to delete.");
    };

    const handleAddItemClick = () => { setNewItemName(""); setCriteriaValues({}); setNewItemImageUrl(""); setItemModalError(""); setShowItemModal(true); };
    const handleItemConfirm = async () => {
        const name = newItemName.trim();
        if (!name) { setItemModalError("Please enter an item name."); return; }
        const result = await onAddItem(name, criteriaValues, newItemImageUrl);
        if (result.success) setShowItemModal(false);
        else setItemModalError(result.error || "Failed to add item.");
    };

    return (
        <div className="home-wrapper">
            <header className="home-header">
                <div className="header-center">
                    <img src="/projectlogo.png" alt="Logo" className="header-logo" />
                    <h1>Collector's Pair-A-Dice</h1>
                </div>
                <button className="logout-btn" onClick={onLogout}>Log Out</button>
            </header>

            <div className="collection-body">
                <aside className="collection-sidebar">
                    <div className="sidebar-scroll" ref={menuRef}>
                        {siblingCollections.map((col) => (
                            <div key={col._id} className="collection-row">
                                <button className={`collection-btn${activeId === col._id ? " active" : ""}`} onClick={() => { setActiveId(col._id); onSiblingSelect(col); }}>{col.collectionName}</button>
                                <div className="col-menu-wrapper">
                                    <button className="col-menu-btn" onClick={(e) => { e.stopPropagation(); setOpenMenuId(openMenuId === col._id ? null : col._id); }}>⋮</button>
                                    {openMenuId === col._id && (
                                        <div className="col-menu-popover">
                                            <button className="col-menu-option" onClick={() => handleEditCollectionClick(col)}>✎ Edit</button>
                                            <button className="col-menu-option col-menu-option-delete" onClick={() => handleDeleteCollectionClick(col)}>✕ Delete</button>
                                        </div>
                                    )}
                                </div>
                            </div>
                        ))}
                    </div>
                </aside>

                <main className="collection-main">
                    <div className="breadcrumb">
                        <span onClick={onNavigateHome}>Home</span>
                        <span className="breadcrumb-sep">&gt;</span>
                        <span onClick={onNavigateCategory}>{categoryName}</span>
                        <span className="breadcrumb-sep">&gt;</span>
                        <span className="breadcrumb-current">{collectionName}</span>
                        <span className="breadcrumb-sep">&gt;</span>
                    </div>

                    <div className="collection-top">
                        <h2 className="collection-title">{collectionName}:</h2>
                        <div className="search-row">
                            <div className="filter-dropdown-wrapper" ref={dropdownRef}>
                                <button className="filter-btn" onClick={() => setDropdownOpen((o) => !o)}>
                                    {filterCriteria || "Filter"}
                                    <span className={`arrow${dropdownOpen ? " open" : ""}`}>▼</span>
                                </button>
                                {dropdownOpen && (
                                    <div className="filter-dropdown">
                                        <div className={`filter-option${filterCriteria === "" ? " selected" : ""}`} onClick={() => { setFilterCriteria(""); setDropdownOpen(false); }}>All</div>
                                        {criteria.map((c) => (
                                            <div key={c._id} className={`filter-option${filterCriteria === c.criteriaName ? " selected" : ""}`} onClick={() => { setFilterCriteria(c.criteriaName); setDropdownOpen(false); }}>{c.criteriaName}</div>
                                        ))}
                                    </div>
                                )}
                            </div>
                            <input className="search-input" type="text" placeholder="Search..." value={searchQuery} onChange={(e) => setSearchQuery(e.target.value)} />
                        </div>
                    </div>

                    <div className="items-grid">
                        <div className="item-card-add" onClick={handleAddItemClick}>
                            <span className="plus-icon">+</span>
                        </div>
                        {filteredItems.map((item) => (
                            <div key={item._id} className="item-card" onClick={() => handleItemClick(item)}>
                                <div className="item-card-body">
                                    {item.imageUrl ? (
                                        <img src={item.imageUrl} alt={item.itemName} className="item-card-image" />
                                    ) : (
                                        <div className="item-card-no-image">No Image</div>
                                    )}
                                </div>
                                <div className="item-card-footer">{item.itemName}</div>
                            </div>
                        ))}
                    </div>
                </main>
            </div>

            {/* View / Edit / Delete Item Modal */}
            {selectedItem && (
                <div className="modal-overlay" onClick={handleCloseItemModal}>
                    <div className="modal-box item-view-box" onClick={(e) => e.stopPropagation()}>
                        <div className="item-view-layout">
                            <div className="item-view-image-panel">
                                {isEditing ? (
                                    <>
                                        {editImageUrl ? <img src={editImageUrl} alt="item" className="item-view-img" /> : <div className="item-view-img-placeholder">No Image</div>}
                                        <button className="image-upload-btn" onClick={() => editFileRef.current?.click()} disabled={uploadingEdit}>{uploadingEdit ? "Uploading..." : "Change Image"}</button>
                                        <input ref={editFileRef} type="file" accept="image/*" style={{ display: "none" }} onChange={handleEditImageChange} />
                                    </>
                                ) : (
                                    selectedItem.imageUrl ? <img src={selectedItem.imageUrl} alt={selectedItem.itemName} className="item-view-img" /> : <div className="item-view-img-placeholder">No Image</div>
                                )}
                            </div>
                            <div className="item-view-fields-panel">
                                <div className="modal-field">
                                    <label className="modal-label">Item Name</label>
                                    {isEditing ? <input type="text" value={editItemName} onChange={(e) => setEditItemName(e.target.value)} autoFocus /> : <p className="item-view-value item-view-name">{selectedItem.itemName}</p>}
                                </div>
                                {criteria.length > 0 && (
                                    <>
                                        <hr className="modal-divider" />
                                        {criteria.map((c) => (
                                            <div className="modal-field" key={c._id}>
                                                <label className="modal-label">{c.criteriaName}</label>
                                                {isEditing ? <input type="text" value={editCriteriaValues[c.criteriaName] || ""} onChange={(e) => setEditCriteriaValues((prev) => ({ ...prev, [c.criteriaName]: e.target.value }))} /> : <p className="item-view-value">{selectedItem.criteriaValues?.[c.criteriaName] || "—"}</p>}
                                            </div>
                                        ))}
                                    </>
                                )}
                            </div>
                        </div>
                        {itemViewError && <p className="error-msg">{itemViewError}</p>}
                        {showDeleteItemConfirm && <p style={{ color: "grey", fontSize: "0.88rem", textAlign: "center" }}>Are you sure you want to delete <span style={{ color: "white" }}>{selectedItem.itemName}?</span></p>}
                        <div className="modal-actions">
                            {!isEditing && !showDeleteItemConfirm && (<><button className="modal-cancel" onClick={handleCloseItemModal}>Close</button><button className="modal-edit" onClick={() => setIsEditing(true)}>Edit</button><button className="modal-delete" onClick={() => setShowDeleteItemConfirm(true)}>Delete</button></>)}
                            {isEditing && (<><button className="modal-cancel" onClick={() => { setIsEditing(false); setItemViewError(""); }}>Cancel</button><button className="modal-confirm" onClick={handleSaveItem}>Save</button></>)}
                            {showDeleteItemConfirm && (<><button className="modal-cancel" onClick={() => setShowDeleteItemConfirm(false)}>Cancel</button><button className="modal-delete" onClick={handleDeleteItem}>Confirm Delete</button></>)}
                        </div>
                    </div>
                </div>
            )}

            {/* Edit Collection Modal */}
            {showEditCollectionModal && (
                <div className="modal-overlay" onClick={() => setShowEditCollectionModal(false)}>
                    <div className="modal-box" onClick={(e) => e.stopPropagation()}>
                        <h3>Edit Collection</h3>
                        <input type="text" value={editCollectionName} onChange={(e) => setEditCollectionName(e.target.value)} onKeyDown={(e) => { if (e.key === "Enter") handleEditCollectionConfirm(); }} autoFocus />
                        {editCollectionError && <p className="error-msg">{editCollectionError}</p>}
                        <div className="modal-actions"><button className="modal-cancel" onClick={() => setShowEditCollectionModal(false)}>Cancel</button><button className="modal-confirm" onClick={handleEditCollectionConfirm}>Save</button></div>
                    </div>
                </div>
            )}

            {/* Delete Collection Modal */}
            {showDeleteCollectionModal && (
                <div className="modal-overlay" onClick={() => setShowDeleteCollectionModal(false)}>
                    <div className="modal-box" onClick={(e) => e.stopPropagation()}>
                        <h3>Delete Collection</h3>
                        <p style={{ color: "gray", fontSize: "0.9rem" }}>Are you sure you want to delete <span style={{ color: "white" }}>{deletingCollection?.collectionName}</span>? This cannot be undone.</p>
                        {deleteCollectionError && <p className="error-msg">{deleteCollectionError}</p>}
                        <div className="modal-actions"><button className="modal-cancel" onClick={() => setShowDeleteCollectionModal(false)}>Cancel</button><button className="modal-delete" onClick={handleDeleteCollectionConfirm}>Delete</button></div>
                    </div>
                </div>
            )}

            {/* Add Item Modal */}
            {showItemModal && (
                <div className="modal-overlay" onClick={() => setShowItemModal(false)}>
                    <div className="modal-box item-add-box" onClick={(e) => e.stopPropagation()}>
                        <h3>New Item</h3>
                        <div className="item-add-layout">
                            <div className="item-view-image-panel">
                                {newItemImageUrl ? <img src={newItemImageUrl} alt="preview" className="item-view-img" /> : <div className="item-view-img-placeholder">No Image</div>}
                                <button className="image-upload-btn" onClick={() => newFileRef.current?.click()} disabled={uploadingNew}>{uploadingNew ? "Uploading..." : "Upload Image"}</button>
                                <input ref={newFileRef} type="file" accept="image/*" style={{ display: "none" }} onChange={handleNewImageChange} />
                            </div>
                            <div className="item-view-fields-panel">
                                <div className="modal-field">
                                    <label className="modal-label">Item Name</label>
                                    <input type="text" placeholder="Name" value={newItemName} onChange={(e) => setNewItemName(e.target.value)} autoFocus />
                                </div>
                                {criteria.length > 0 && (
                                    <>
                                        <hr className="modal-divider" />
                                        {criteria.map((c) => (
                                            <div className="modal-field" key={c._id}>
                                                <label className="modal-label">{c.criteriaName}</label>
                                                <input type="text" placeholder={c.criteriaName} value={criteriaValues[c.criteriaName] || ""} onChange={(e) => setCriteriaValues((prev) => ({ ...prev, [c.criteriaName]: e.target.value }))} />
                                            </div>
                                        ))}
                                    </>
                                )}
                            </div>
                        </div>
                        {itemModalError && <p className="error-msg">{itemModalError}</p>}
                        <div className="modal-actions"><button className="modal-cancel" onClick={() => setShowItemModal(false)}>Cancel</button><button className="modal-confirm" onClick={handleItemConfirm}>Add Item</button></div>
                    </div>
                </div>
            )}
        </div>
    );
};

export default Collection;

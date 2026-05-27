/* FinFlow - SQL Files Browser */
const SQL_FILES = [
    { id: '1_er', name: '1_ER_Diagram.sql', label: 'ER Diagram', icon: 'fa-project-diagram' },
    { id: '2_norm', name: '2_Normalization.sql', label: 'Normalization', icon: 'fa-check-double' },
    { id: '3_ddl', name: '3_DDL_CreateTables.sql', label: 'DDL (Tables)', icon: 'fa-table' },
    { id: '4_dml', name: '4_DML_SampleData.sql', label: 'DML (Data)', icon: 'fa-database' },
    { id: '5_queries', name: '5_Queries.sql', label: 'Queries', icon: 'fa-search' },
    { id: '6_views', name: '6_Views.sql', label: 'Views', icon: 'fa-eye' },
    { id: '7_procs', name: '7_Procedures.sql', label: 'Procedures', icon: 'fa-cogs' },
    { id: '8_funcs', name: '8_Functions.sql', label: 'Functions', icon: 'fa-calculator' },
    { id: '9_triggers', name: '9_Triggers.sql', label: 'Triggers', icon: 'fa-bolt' },
    { id: '10_txns', name: '10_Transactions.sql', label: 'Transactions', icon: 'fa-exchange-alt' },
    { id: '11_cursors', name: '11_Cursors.sql', label: 'Cursors', icon: 'fa-list-ol' }
];

const sqlFileCache = {};

function renderSQLFileTabs() {
    const container = document.getElementById('sqlFileTabs');
    if (!container) return;
    container.innerHTML = SQL_FILES.map((f, i) =>
        `<button class="sql-file-tab ${i === 0 ? 'active' : ''}" data-file="${f.name}" onclick="loadSQLFile('${f.name}', this)">
            <i class="fas ${f.icon}" style="margin-right:4px"></i>${f.label}
        </button>`
    ).join('');
    // Load first file automatically
    loadSQLFile(SQL_FILES[0].name, container.querySelector('.sql-file-tab'));
}

function loadSQLFile(filename, tabEl) {
    // Update active tab
    document.querySelectorAll('.sql-file-tab').forEach(t => t.classList.remove('active'));
    if (tabEl) tabEl.classList.add('active');

    document.getElementById('sqlFileTitle').textContent = filename;

    // Check cache first
    if (sqlFileCache[filename]) {
        displaySQLFile(filename, sqlFileCache[filename]);
        return;
    }

    // Fetch from sql/ directory
    document.getElementById('sqlFileContent').querySelector('code').textContent = 'Loading...';
    fetch('sql/' + filename)
        .then(r => {
            if (!r.ok) throw new Error('File not found');
            return r.text();
        })
        .then(content => {
            sqlFileCache[filename] = content;
            displaySQLFile(filename, content);
        })
        .catch(err => {
            document.getElementById('sqlFileContent').querySelector('code').textContent =
                '-- Error loading file: ' + err.message + '\n-- Make sure you are running from a web server (not file://).\n-- Tip: Use "python -m http.server 8000" or VS Code Live Server.';
            document.getElementById('sqlFileSize').textContent = 'Error';
        });
}

function displaySQLFile(filename, content) {
    // Syntax highlight the SQL
    const highlighted = highlightSQL(content);
    document.getElementById('sqlFileContent').querySelector('code').innerHTML = highlighted;

    const lines = content.split('\n').length;
    const size = new Blob([content]).size;
    const sizeKB = (size / 1024).toFixed(1);
    document.getElementById('sqlFileSize').textContent = `${lines} lines · ${sizeKB} KB`;
}

function highlightSQL(code) {
    // Escape HTML first
    let html = code
        .replace(/&/g, '&amp;')
        .replace(/</g, '&lt;')
        .replace(/>/g, '&gt;');

    // SQL keywords
    const keywords = [
        'SELECT','FROM','WHERE','INSERT','INTO','VALUES','UPDATE','SET',
        'DELETE','CREATE','DROP','ALTER','TABLE','VIEW','INDEX','SEQUENCE',
        'PRIMARY','FOREIGN','KEY','REFERENCES','CONSTRAINT','CHECK','NOT',
        'NULL','UNIQUE','DEFAULT','ON','CASCADE','RESTRICT','AND','OR',
        'JOIN','LEFT','RIGHT','INNER','OUTER','FULL','CROSS','NATURAL',
        'GROUP','BY','ORDER','HAVING','AS','IN','EXISTS','BETWEEN','LIKE',
        'IS','CASE','WHEN','THEN','ELSE','END','UNION','ALL','DISTINCT',
        'COUNT','SUM','AVG','MIN','MAX','NVL','ROUND','COALESCE','EXTRACT',
        'FUNCTION','PROCEDURE','TRIGGER','CURSOR','DECLARE','BEGIN','EXCEPTION',
        'RAISE','RETURN','IF','ELSIF','LOOP','FETCH','EXIT','OPEN','CLOSE',
        'COMMIT','ROLLBACK','SAVEPOINT','REPLACE','FOR','EACH','ROW',
        'AFTER','BEFORE','INSERTING','UPDATING','DELETING','NEW','OLD',
        'NUMBER','VARCHAR2','DATE','TIMESTAMP','CLOB','BOOLEAN','DECIMAL','INT',
        'WITH','RECURSIVE','OVER','PARTITION','ROWNUM','LEVEL','CONNECT',
        'START','PRIOR','SIBLINGS','DBMS_OUTPUT','PUT_LINE','RAISE_APPLICATION_ERROR',
        'TYPE','RECORD','ROWTYPE','BULK','COLLECT','SYS_REFCURSOR','NEXTVAL',
        'TO_CHAR','TO_DATE','TO_NUMBER','TO_TIMESTAMP','SYSDATE','TRUNC',
        'ADD_MONTHS','LAST_DAY','MONTHS_BETWEEN','POWER','GREATEST','LEAST',
        'LPAD','RPAD','SUBSTR','INSTR','TRIM','UPPER','LOWER','REGEXP_LIKE',
        'CURRENT_TIMESTAMP','USER','VARCHAR','INTERVAL','ROWS','ONLY','FIRST'
    ];

    // Highlight block comments /* ... */
    html = html.replace(/(\/\*[\s\S]*?\*\/)/g, '<span style="color:#5a6380;font-style:italic">$1</span>');

    // Highlight single-line comments -- ...
    html = html.replace(/(--[^\n]*)/g, '<span style="color:#5a6380;font-style:italic">$1</span>');

    // Highlight strings 'text'
    html = html.replace(/('(?:[^'\\]|\\.)*')/g, '<span style="color:#feca57">$1</span>');

    // Highlight numbers
    html = html.replace(/\b(\d+\.?\d*)\b/g, '<span style="color:#fd79a8">$1</span>');

    // Highlight keywords (only outside comments/strings - simple approach)
    keywords.forEach(kw => {
        const re = new RegExp('\\b(' + kw + ')\\b(?![^<]*>)', 'gi');
        html = html.replace(re, '<span style="color:#54a0ff;font-weight:600">$1</span>');
    });

    return html;
}

// Hook into the page navigation system
const origNavigate = window.navigate || function(){};
const patchedNavigate = function(page) {
    origNavigate(page);
    if (page === 'sqlfiles') {
        renderSQLFileTabs();
    }
};

// Override navigate after DOM loaded
document.addEventListener('DOMContentLoaded', () => {
    // Patch the navigate function
    const oldNav = window.navigate;
    window.navigate = function(page) {
        oldNav(page);
        if (page === 'sqlfiles') renderSQLFileTabs();
    };
});

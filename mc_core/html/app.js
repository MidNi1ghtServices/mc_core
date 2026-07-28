/* ===========================================================
   INSURANCE STATE
=========================================================== */

let currentInsuranceContext = null;

/* ===========================================================
   CRAFTER STATE
=========================================================== */

let selectedCraft = null;
let selectedZone = null;
let allCrafts = [];

/* ===========================================================
   LABOR STATE
=========================================================== */

let laborTimer = null;

/* ===========================================================
   VERKAUF STATE
=========================================================== */

let currentVerkaufRoute = null;

/* ===========================================================
   NUI EVENTS
   Erwartete Actions:
     openInsurance { tiers?, ...context }
     closeInsurance
     insuranceResult { message, success }
     openCrafter  { zone, crafts, queue? }
     closeCrafter
     updateQueue  { queue }
     openLabor    { labor }
     closeLabor
     updateLabor  { items, money, finish, duration }
     openVerkauf  { ... }
     closeVerkauf
     verkaufResult
=========================================================== */

window.addEventListener("message", function (event) {
    const data = event.data;

    switch (data.action) {

        case "openInsurance":
            openInsurance(data);
            break;

        case "closeInsurance":
            closeInsurance();
            break;

        case "insuranceResult":
            showInsuranceResult(data);
            break;

        case "openCrafter":
            openCrafter(data);
            break;

        case "closeCrafter":
            closeCrafter();
            break;

        case "updateQueue":
            updateQueue(data.queue || []);
            break;

        case "openLabor":
            openLabor(data);
            break;

        case "closeLabor":
            closeLabor();
            break;

        case "updateLabor":
            updateLabor(data.labor || data);
            break;

        case "openVerkauf":
            openVerkauf(data);
            break;

        case "closeVerkauf":
            closeVerkauf();
            break;

        case "verkaufResult":
            showVerkaufResult(data);
            break;

        case "openMoneywash":
            openMoneywash(data);
            break;

        case "closeMoneywash":
            closeMoneywash();
            break;

        case "updateMoneywash":
            updateMoneywash(data);
            break;

        case "openRevive":
            openRevive(data);
            break;

        case "closeRevive":
            closeRevive();
            break;

        /* -------------------------------------------------
           Legacy-Namen (falls Lua-Seite noch "open"/"close"
           statt der neuen getrennten Actions schickt).
           "open" wird anhand der Daten der richtigen UI
           zugeordnet: hat "crafts" -> Crafter, sonst -> Labor.
        ------------------------------------------------- */

        case "open":
            if (data.crafts || data.mode === "crafter") {
                openCrafter(data);
            } else {
                openLabor(data);
            }
            break;

        case "close":
            closeCrafter();
            closeLabor();
            closeVerkauf();
            closeInsurance();
            closeMoneywash();
            closeRevive();
            break;

    }
});

/* ===========================================================
   INSURANCE UI (eigenständig)
=========================================================== */

function openInsurance(data) {

    document.getElementById("insuranceApp").classList.remove("hidden");

    currentInsuranceContext = {
        plate: data.plate || null,
        zone: data.zone || null
    };

    document.querySelectorAll("#insuranceTiers .tier-btn").forEach(btn => {
        btn.classList.remove("active");
    });

    document.querySelectorAll("[data-price-for]").forEach(el => {
        const tier = el.getAttribute("data-price-for");
        const info = data.tiers && data.tiers[tier];

        el.innerText = info && info.price != null ? `$${info.price}` : "";
    });

    const feedback = document.getElementById("insuranceFeedback");
    feedback.innerText = "";

}

function closeInsurance() {

    document.getElementById("insuranceApp").classList.add("hidden");
    currentInsuranceContext = null;

}

function requestCloseInsurance() {

    closeInsurance();

    fetch(`https://${GetParentResourceName()}/closeInsurance`, {
        method: "POST"
    }).catch(() => {});

}

document.getElementById("insuranceCloseBtn").onclick = requestCloseInsurance;

document.querySelectorAll("#insuranceTiers .tier-btn").forEach(btn => {

    btn.onclick = function () {

        const tier = btn.getAttribute("data-tier");

        document.querySelectorAll("#insuranceTiers .tier-btn").forEach(b => {
            b.classList.remove("active");
        });
        btn.classList.add("active");

        fetch(`https://${GetParentResourceName()}/selectInsurance`, {
            method: "POST",
            body: JSON.stringify({
                tier: tier,
                plate: currentInsuranceContext ? currentInsuranceContext.plate : null,
                zone: currentInsuranceContext ? currentInsuranceContext.zone : null
            })
        }).catch(() => {});

    };

});

function showInsuranceResult(data) {

    const feedback = document.getElementById("insuranceFeedback");
    feedback.innerText = data.message || "";
    feedback.style.color = data.success ? "var(--cash)" : "var(--danger)";

}

/* ===========================================================
   CRAFTER UI
=========================================================== */

function openCrafter(data) {

    selectedZone = data.zone;
    document.getElementById("crafterApp").classList.remove("hidden");

    loadCrafts(data.crafts || []);

    if (data.queue) {
        updateQueue(data.queue);
    }

}

function closeCrafter() {

    document.getElementById("crafterApp").classList.add("hidden");

    selectedCraft = null;
    selectedZone = null;
    allCrafts = [];

    document.getElementById("craftItems").innerHTML = "";
    document.getElementById("searchInput").value = "";
    document.getElementById("detailContent").innerHTML =
        `<div class="empty-state">Wähle links ein Rezept aus.</div>`;
    document.getElementById("craftButton").disabled = true;

    document.getElementById("queueItems").innerHTML =
        `<div class="empty-state small">Keine aktiven Aufträge.</div>`;

}

function requestCloseCrafter() {

    closeCrafter();

    fetch(`https://${GetParentResourceName()}/closeCrafter`, {
        method: "POST"
    }).catch(() => {});

}

document.getElementById("crafterCloseBtn").onclick = requestCloseCrafter;

/* ---------- Liste / Suche ---------- */

function loadCrafts(crafts) {

    allCrafts = crafts;
    renderCraftList(crafts);

}

function renderCraftList(crafts) {

    const list = document.getElementById("craftItems");
    list.innerHTML = "";

    if (!crafts.length) {
        list.innerHTML = `<div class="empty-state small">Keine Rezepte gefunden.</div>`;
        return;
    }

    crafts.forEach(craft => {

        const div = document.createElement("div");
        div.className = "list-item";

        if (selectedCraft && selectedCraft.name === craft.name) {
            div.classList.add("active");
        }

        div.innerHTML = `<strong>${craft.label}</strong>`;

        div.onclick = () => selectCraft(craft);

        list.appendChild(div);

    });

}

document.getElementById("searchInput").addEventListener("input", function (e) {

    const query = e.target.value.trim().toLowerCase();

    const filtered = allCrafts.filter(craft =>
        craft.label.toLowerCase().includes(query)
    );

    renderCraftList(filtered);

});

function selectCraft(craft) {

    selectedCraft = craft;

    renderCraftList(
        allCrafts.filter(c =>
            c.label.toLowerCase().includes(
                document.getElementById("searchInput").value.trim().toLowerCase()
            )
        )
    );

    document.getElementById("detailContent").innerHTML = `
        <div class="block">
            <span class="label">Produkt</span>
            ${craft.label}
        </div>

        <div class="block">
            <span class="label">Herstellungszeit</span>
            ${craft.craftingTime} Sekunden
        </div>

        <div class="block">
            <span class="label">Belohnung</span>
            ${craft.reward.amount}x ${craft.reward.item}
        </div>

        <div class="block">
            <span class="label">Zutaten</span>
            ${Object.entries(craft.ingredients)
                .map(([item, amount]) => `
                    <div class="ingredient-row">
                        <span>${item}</span>
                        <strong>${amount}x</strong>
                    </div>
                `)
                .join("")}
        </div>
    `;

    document.getElementById("craftButton").disabled = false;

}

document.getElementById("craftButton").onclick = function () {

    if (!selectedCraft || !selectedZone) return;

    const amount = Math.max(
        1,
        Number(document.getElementById("quantityInput").value) || 1
    );

    fetch(`https://${GetParentResourceName()}/craft`, {
        method: "POST",
        body: JSON.stringify({

            zone: selectedZone,
            craft: selectedCraft.name,
            amount: amount

        })
    });

};

/* ---------- Warteschlange ---------- */

function updateQueue(queue) {

    const container = document.getElementById("queueItems");
    container.innerHTML = "";

    if (!queue || !queue.length) {
        container.innerHTML = `<div class="empty-state small">Keine aktiven Aufträge.</div>`;
        return;
    }

    queue.forEach(entry => {

        const div = document.createElement("div");
        div.className = "queue-item";

        if (entry.collectable) {

            div.classList.add("ready");

            div.innerHTML = `
                <span>${entry.label || entry.name}</span>
                <span class="qty">${entry.amount ? entry.amount + "x" : ""}</span>
                <button class="collect-btn">Abholen</button>
            `;

            div.querySelector(".collect-btn").onclick = () => collectCraft(entry.id);

        } else {

            div.innerHTML = `
                <span>${entry.label || entry.name}</span>
                <span class="qty">${entry.amount ? entry.amount + "x" : ""}</span>
                <span class="status">${entry.status || "In Arbeit"}</span>
            `;

        }

        container.appendChild(div);

    });

}

function collectCraft(id) {

    fetch(`https://${GetParentResourceName()}/collectCraft`, {
        method: "POST",
        body: JSON.stringify({ id: id })
    }).catch(() => {});

}

/* ===========================================================
   LABOR UI (komplett eigenständig)
=========================================================== */

function openLabor(data) {

    document.getElementById("laborApp").classList.remove("hidden");

    document.getElementById("laborTitle").innerText = data.label || "Labor";

    // "data.labor" ist hier nur die Labor-ID/Name, nicht die
    // Statuswerte. Die echten Werte (items/money/finish) kommen
    // kurz danach per separater "updateLabor"-Nachricht vom Server.
    updateLabor({ items: 0, money: 0, finish: 0 });

}

function closeLabor() {

    document.getElementById("laborApp").classList.add("hidden");

    if (laborTimer) {
        clearInterval(laborTimer);
        laborTimer = null;
    }

}

function requestCloseLabor() {

    closeLabor();

    fetch(`https://${GetParentResourceName()}/closeLabor`, {
        method: "POST"
    }).catch(() => {});

}

document.getElementById("laborCloseBtn").onclick = requestCloseLabor;

function updateLabor(data) {

    document.getElementById("laborItems").innerText = data.items || 0;
    document.getElementById("laborMoney").innerText = data.money || 0;

    if (laborTimer)
        clearInterval(laborTimer);

    const total = data.duration || null;

    function updateCountdown() {

        if (!data.finish || data.finish <= 0) {

            document.getElementById("laborTime").innerText = "00:00";
            document.getElementById("laborProgress").style.width = "0%";
            return;

        }

        const diff = data.finish - Date.now();

        if (diff <= 0) {

            document.getElementById("laborTime").innerText = "Fertig!";
            document.getElementById("laborProgress").style.width = "100%";

            clearInterval(laborTimer);

            return;

        }

        const min = Math.floor(diff / 60000);
        const sec = Math.floor((diff % 60000) / 1000);

        document.getElementById("laborTime").innerText =
            `${min}:${sec.toString().padStart(2, "0")}`;

        if (total) {
            const pct = Math.max(0, Math.min(100, 100 - (diff / total) * 100));
            document.getElementById("laborProgress").style.width = `${pct}%`;
        }

    }

    updateCountdown();

    laborTimer = setInterval(updateCountdown, 1000);

}

document.getElementById("laborDeposit").onclick = function () {

    const amount =
        Number(document.getElementById("laborAmount").value) || 0;

    if (amount <= 0) return;

    fetch(`https://${GetParentResourceName()}/deposit`, {
        method: "POST",
        body: JSON.stringify({
            amount: amount
        })
    });

    document.getElementById("laborAmount").value = "";

};

document.getElementById("laborCollect").onclick = function () {

    fetch(`https://${GetParentResourceName()}/collect`, {
        method: "POST"
    });

};

/* ===========================================================
   ESC SCHLIESST DAS JEWEILS OFFENE UI
=========================================================== */

document.addEventListener("keydown", function (e) {

    if (e.key !== "Escape") return;

    if (!document.getElementById("insuranceApp").classList.contains("hidden")) {
        requestCloseInsurance();
    }

    if (!document.getElementById("crafterApp").classList.contains("hidden")) {
        requestCloseCrafter();
    }

    if (!document.getElementById("laborApp").classList.contains("hidden")) {
        requestCloseLabor();
    }

    if (!document.getElementById("verkaufApp").classList.contains("hidden")) {
        requestCloseVerkauf();
    }

    if (!document.getElementById("moneywashApp").classList.contains("hidden")) {
        requestCloseMoneywash();
    }

    if (!document.getElementById("reviveApp").classList.contains("hidden")) {
        requestCloseRevive();
    }

});

/* ===========================================================
   VERKAUF UI (eigenständig)
=========================================================== */

function openVerkauf(data) {

    document.getElementById("verkaufApp").classList.remove("hidden");

    currentVerkaufRoute = data.route;

    document.getElementById("verkaufTitle").innerText = data.label || "Verkauf";
    document.getElementById("verkaufItem").innerText = data.item || "-";
    document.getElementById("verkaufAnzahl").innerText = data.anzahl || 1;

    if (data.priceRange && data.priceRange.enabled) {
        document.getElementById("verkaufPrice").innerText = `${data.priceRange.min}–${data.priceRange.max}`;
    } else {
        document.getElementById("verkaufPrice").innerText = data.price || 0;
    }

    document.getElementById("verkaufAmount").value = 1;

    const feedback = document.getElementById("verkaufFeedback");
    feedback.innerText = "";

}

function closeVerkauf() {

    document.getElementById("verkaufApp").classList.add("hidden");
    currentVerkaufRoute = null;

}

function requestCloseVerkauf() {

    closeVerkauf();

    fetch(`https://${GetParentResourceName()}/closeVerkauf`, {
        method: "POST"
    }).catch(() => {});

}

document.getElementById("verkaufCloseBtn").onclick = requestCloseVerkauf;

document.getElementById("verkaufSellBtn").onclick = function () {

    if (!currentVerkaufRoute) return;

    const amount = Math.max(
        1,
        Number(document.getElementById("verkaufAmount").value) || 1
    );

    fetch(`https://${GetParentResourceName()}/sellVerkauf`, {
        method: "POST",
        body: JSON.stringify({ amount: amount })
    }).catch(() => {});

};

function showVerkaufResult(data) {

    const feedback = document.getElementById("verkaufFeedback");
    feedback.innerText = data.message || "";
    feedback.style.color = data.success ? "var(--cash)" : "var(--danger)";

}
/* ===========================================================
   MONEYWASH UI (eigenständig)
=========================================================== */

let mwConfig = null;          // { packages, custom, minFee, maxFee }
let mwSelectedPackage = null;
let mwJobs = [];
let mwClockOffset = 0;        // serverNow - localNow (Sekunden)
let mwTickInterval = null;

function formatMoneyMW(n) {
    n = Math.max(0, Math.round(n || 0));
    return n.toLocaleString("de-DE") + "$";
}

function formatHoursMW(minutes) {
    return (minutes / 60).toFixed(1) + "h";
}

function mwServerNow() {
    return (Date.now() / 1000) + mwClockOffset;
}

function openMoneywash(data) {

    document.getElementById("moneywashApp").classList.remove("hidden");

    mwConfig = data.config;
    mwSelectedPackage = null;

    document.getElementById("mwFeeNote").innerText =
        `Die Gebühren betragen zwischen ${mwConfig.minFee ?? 5} und ${mwConfig.maxFee ?? 50}%`;

    document.getElementById("mwCustomAmount").value = "";

    setMoneywashTab("wash");
    renderMoneywashPackages();
    updateMoneywashPreview();

}

function closeMoneywash() {

    document.getElementById("moneywashApp").classList.add("hidden");

    if (mwTickInterval) {
        clearInterval(mwTickInterval);
        mwTickInterval = null;
    }

    mwConfig = null;
    mwSelectedPackage = null;
    mwJobs = [];

}

function requestCloseMoneywash() {

    closeMoneywash();

    fetch(`https://${GetParentResourceName()}/closeMoneywash`, {
        method: "POST"
    }).catch(() => {});

}

document.getElementById("moneywashCloseBtn").onclick = requestCloseMoneywash;

/* ---------- Tabs ---------- */

function setMoneywashTab(tab) {

    document.querySelectorAll(".mw-tab").forEach(btn => {
        btn.classList.toggle("active", btn.getAttribute("data-mwtab") === tab);
    });

    document.getElementById("mwTabWash").classList.toggle("active", tab === "wash");
    document.getElementById("mwTabJobs").classList.toggle("active", tab === "jobs");

}

document.querySelectorAll(".mw-tab").forEach(btn => {
    btn.onclick = () => setMoneywashTab(btn.getAttribute("data-mwtab"));
});

/* ---------- Status vom Server ---------- */

function updateMoneywash(data) {

    document.getElementById("mwBlackAvailable").innerText = formatMoneyMW(data.blackMoney);
    document.getElementById("mwCleanAvailable").innerText = formatMoneyMW(data.cleanMoney);

    mwJobs = data.jobs || [];
    mwClockOffset = (data.now || (Date.now() / 1000)) - (Date.now() / 1000);

    renderMoneywashJobs();

}

/* ---------- Pakete ---------- */

function renderMoneywashPackages() {

    const list = document.getElementById("mwPackageList");
    list.innerHTML = "";

    (mwConfig.packages || []).forEach((pkg, idx) => {

        const card = document.createElement("div");
        card.className = "mw-package-card";
        card.dataset.id = pkg.id;

        card.innerHTML = `
            <div class="mw-package-top">
                <span class="mw-package-id">#${idx + 1}</span>
                <span class="mw-badge mw-badge-red">${pkg.fee}%</span>
            </div>
            <div class="mw-package-row"><span>Bargeld</span><strong>${formatMoneyMW(pkg.amount)}</strong></div>
            <div class="mw-package-row"><span>Zeit</span><strong>${formatHoursMW(pkg.time)}</strong></div>
        `;

        card.onclick = () => {
            mwSelectedPackage = (mwSelectedPackage && mwSelectedPackage.id === pkg.id) ? null : pkg;
            document.getElementById("mwCustomAmount").value =
                mwSelectedPackage ? mwSelectedPackage.amount : "";
            renderMoneywashPackageSelection();
            updateMoneywashPreview();
        };

        list.appendChild(card);

    });

}

function renderMoneywashPackageSelection() {

    document.querySelectorAll(".mw-package-card").forEach(card => {
        card.classList.toggle(
            "selected",
            mwSelectedPackage && String(mwSelectedPackage.id) === card.dataset.id
        );
    });

}

/* ---------- Freier Betrag ---------- */

function mwComputeCustomFee(amount) {
    const tiers = mwConfig.custom.feeTiers;
    for (const t of tiers) {
        if (amount <= t.upto) return t.fee;
    }
    return tiers[tiers.length - 1].fee;
}

function mwComputeCustomTime(amount) {
    let minutes = mwConfig.custom.baseTimeMinutes + (amount / 1000000) * mwConfig.custom.minutesPerMillion;
    return Math.min(minutes, mwConfig.custom.maxTimeMinutes);
}

function mwParsedCustomAmount() {
    const raw = (document.getElementById("mwCustomAmount").value || "").toString().replace(/[^\d]/g, "");
    return raw ? parseInt(raw, 10) : 0;
}

function updateMoneywashPreview() {

    if (!mwConfig) return;

    let amount, fee, timeMinutes;

    if (mwSelectedPackage) {
        amount = mwSelectedPackage.amount;
        fee = mwSelectedPackage.fee;
        timeMinutes = mwSelectedPackage.time;
    } else {
        amount = mwParsedCustomAmount();
        fee = amount > 0 ? mwComputeCustomFee(amount) : 0;
        timeMinutes = amount > 0 ? mwComputeCustomTime(amount) : 0;
    }

    const clean = amount - (amount * (fee / 100));

    document.getElementById("mwCustomFeeBadge").innerText = fee + "%";
    document.getElementById("mwCustomClean").innerText = formatMoneyMW(clean);
    document.getElementById("mwCustomTime").innerText = formatHoursMW(timeMinutes);

    document.getElementById("mwConfirmBtn").disabled =
        amount <= 0 || (!mwSelectedPackage && amount < mwConfig.custom.minAmount);

}

document.getElementById("mwCustomAmount").addEventListener("input", () => {
    mwSelectedPackage = null;
    renderMoneywashPackageSelection();
    updateMoneywashPreview();
});

document.getElementById("mwConfirmBtn").onclick = function () {

    if (document.getElementById("mwConfirmBtn").disabled) return;

    const payload = mwSelectedPackage
        ? { type: "package", packageId: mwSelectedPackage.id }
        : { type: "custom", amount: mwParsedCustomAmount() };

    fetch(`https://${GetParentResourceName()}/startMoneywash`, {
        method: "POST",
        body: JSON.stringify(payload)
    }).catch(() => {});

    mwSelectedPackage = null;
    document.getElementById("mwCustomAmount").value = "";
    renderMoneywashPackageSelection();
    updateMoneywashPreview();
    setMoneywashTab("jobs");

};

/* ---------- Aktive Jobs ---------- */

function renderMoneywashJobs() {

    const container = document.getElementById("mwJobsList");
    container.innerHTML = "";

    if (!mwJobs.length) {
        container.innerHTML = `<div class="empty-state small">Keine aktiven Wäschen.</div>`;
        if (mwTickInterval) {
            clearInterval(mwTickInterval);
            mwTickInterval = null;
        }
        return;
    }

    mwJobs.forEach(job => {

        const div = document.createElement("div");
        div.className = "queue-item";
        div.dataset.id = job.id;

        div.innerHTML = `
            <span>${formatMoneyMW(job.amount)} <span class="qty">(-${job.fee}%)</span></span>
            <span class="status mw-job-status"></span>
            <div class="progress-track mw-job-progress" style="flex-basis:100%"><div class="progress-fill"></div></div>
            <button class="collect-btn" disabled>Abholen</button>
        `;

        div.querySelector(".collect-btn").onclick = () => {
            div.querySelector(".collect-btn").disabled = true;
            fetch(`https://${GetParentResourceName()}/collectMoneywash`, {
                method: "POST",
                body: JSON.stringify({ jobId: job.id })
            }).catch(() => {});
        };

        container.appendChild(div);

    });

    if (mwTickInterval) clearInterval(mwTickInterval);
    tickMoneywashJobs();
    mwTickInterval = setInterval(tickMoneywashJobs, 1000);

}

function tickMoneywashJobs() {

    const now = mwServerNow();

    mwJobs.forEach(job => {

        const card = document.querySelector(`#mwJobsList .queue-item[data-id="${job.id}"]`);
        if (!card) return;

        const total = job.finish_at - job.started_at;
        const elapsed = Math.min(Math.max(now - job.started_at, 0), total);
        const pct = total > 0 ? (elapsed / total) * 100 : 100;

        card.querySelector(".progress-fill").style.width = pct + "%";

        const remaining = Math.max(0, Math.round(job.finish_at - now));
        const statusEl = card.querySelector(".mw-job-status");
        const collectBtn = card.querySelector(".collect-btn");

        if (remaining <= 0) {
            statusEl.innerText = "Bereit";
            card.classList.add("ready");
            collectBtn.disabled = false;
        } else {
            const m = Math.floor(remaining / 60).toString().padStart(2, "0");
            const s = (remaining % 60).toString().padStart(2, "0");
            statusEl.innerText = `${m}:${s}`;
            card.classList.remove("ready");
            collectBtn.disabled = true;
        }

    });

}

/* ===========================================================
   REVIVE STATION UI (eigenständig, Originaldesign)
=========================================================== */

function openRevive(data) {

    document.getElementById("reviveApp").classList.remove("hidden");
    document.getElementById("ws-price").innerText = "Kosten: $" + data.price;

}

function closeRevive() {

    document.getElementById("reviveApp").classList.add("hidden");

}

function requestCloseRevive() {

    closeRevive();

    fetch(`https://${GetParentResourceName()}/closeRevive`, {
        method: "POST"
    }).catch(() => {});

}

document.getElementById("ws-close").onclick = requestCloseRevive;

document.getElementById("ws-revive").onclick = function () {

    fetch(`https://${GetParentResourceName()}/startRevive`, {
        method: "POST"
    }).catch(() => {});

};

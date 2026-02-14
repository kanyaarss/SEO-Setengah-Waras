defmodule ElixirNawalaDK168Web.AdminDashboardLive do
  use ElixirNawalaDK168Web, :live_view

  alias ElixirNawalaDK168.Monitor
  alias ElixirNawalaDK168.Telegram.Notifier
  @api_time_offset_seconds 25_200

  on_mount {ElixirNawalaDK168Web.AdminAuth, :require_authenticated_admin}

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      Monitor.subscribe_dashboard()
      :timer.send_interval(1_000, :status_tick)
    end

    domains = Monitor.list_domains()
    settings = Monitor.list_settings()

    {:ok,
     socket
     |> assign(:page_title, "Admin Dashboard")
     |> assign_domains(domains)
     |> assign(:settings, settings)
     |> assign(:add_domain_profiles, [])
     |> assign(:domain_form, to_form(%{"name" => "", "profile_id" => ""}, as: :domain))
     |> assign(:settings_form, to_form(settings, as: :settings))
     |> assign(:test_message, "[ElixirNawalaDK168] Test notifikasi Telegram")
     |> assign(:last_cycle_info, nil)
     |> assign(:current_page, :home)
     |> assign(:remote_domains, [])
     |> assign(:remote_statuses, %{})
     |> assign(:sflink_profile, nil)
     |> assign(:sflink_profiles, [])
     |> assign(:max_sflink_profiles, Monitor.max_sflink_profiles())
     |> assign(:list_domain_query, "")
     |> assign(:sflink_profile_form, to_form(%{"name" => "", "api_token" => ""}, as: :sflink_profile))
     |> assign(:status_clock, DateTime.utc_now())
     |> assign(:next_refresh_seconds, 20)
     |> assign(:sidebar_collapsed, false)
     |> assign(:sidebar_open, false)
     |> assign(:domain_menu_open, false)
     |> assign(:admin_menu_open, false)
     |> assign_remote_domains()}
  end

  @impl true
  def handle_params(_params, _uri, socket) do
    page = page_from_action(socket.assigns.live_action)

    socket =
      socket
      |> assign(:current_page, page)
      |> assign(:page_title, page_title(page))
      |> assign(:domain_menu_open, page in [:add_domain, :list_domain, :status_domain])
      |> assign(:admin_menu_open, page in [:profile])

    socket =
      case page do
        :list_domain ->
          socket
          |> sync_remote_domains()
          |> assign_domains(Monitor.list_domains())
          |> assign_remote_domains()
          |> live_check_all_remote_domains()

        :status_domain ->
          socket
          |> assign_remote_domains()
          |> live_check_all_remote_domains()
          |> assign_next_refresh_seconds()

        :add_domain ->
          socket
          |> assign_add_domain_profiles()

        :profile ->
          socket
          |> assign_sflink_profile()
          |> assign(:sflink_profiles, Monitor.list_sflink_profiles())

        :telegram ->
          settings = Monitor.list_settings()

          socket
          |> assign(:settings, settings)
          |> assign(:settings_form, to_form(settings, as: :settings))

        _ ->
          socket
      end

    {:noreply, socket}
  end

  @impl true
  def handle_event("create_domain", %{"domain" => params}, socket) do
    case Monitor.create_domain_from_sflink(params) do
      {:ok, %{local_domain: local_domain, sflink: sflink}} ->
        domains = Monitor.list_domains()
        socket = assign_add_domain_profiles(socket)
        default_profile_id = default_add_domain_profile_id(socket.assigns.add_domain_profiles)

        {:noreply,
         socket
         |> put_flash(:info, "SFLINK OK: #{sflink.domain || local_domain.name} (id: #{sflink.id || "-"})")
         |> assign_domains(domains)
         |> assign(:domain_form, to_form(%{"name" => "", "profile_id" => default_profile_id}, as: :domain))}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply,
         socket
         |> put_flash(:error, "Gagal kirim domain ke SFLINK: ERROR DIRECTLY CALL 911 RAKA GANTENG")
         |> assign(:domain_form, to_form(changeset, as: :domain))}

      {:error, :missing_profile_selection} ->
        {:noreply, put_flash(socket, :error, "Pilih User Profile terlebih dahulu.")}

      {:error, :invalid_profile_selection} ->
        {:noreply, put_flash(socket, :error, "User Profile tidak valid.")}

      {:error, :inactive_profile} ->
        {:noreply, put_flash(socket, :error, "User Profile tidak aktif.")}

      {:error, :profile_not_found} ->
        {:noreply, put_flash(socket, :error, "User Profile tidak ditemukan.")}

      {:error, reason} ->
        _ = format_reason(reason)
        {:noreply, socket |> put_flash(:error, "Gagal kirim domain ke SFLINK: ERROR DIRECTLY CALL 911 RAKA GANTENG")}
    end
  end

  def handle_event("toggle_domain", %{"id" => id}, socket) do
    case Monitor.toggle_domain(String.to_integer(id)) do
      {:ok, _domain} ->
        domains = Monitor.list_domains()
        {:noreply, socket |> put_flash(:info, "Status domain diperbarui.") |> assign_domains(domains)}

      {:error, _reason} ->
        {:noreply, put_flash(socket, :error, "Gagal mengubah status domain.")}
    end
  end

  def handle_event("delete_domain", %{"id" => id}, socket) do
    case Monitor.delete_domain_from_sflink(String.to_integer(id)) do
      {:ok, %{local_name: name, remote_id: remote_id}} ->
        {:noreply,
         socket
         |> put_flash(:info, "Domain #{name} deleted (SFLINK id: #{remote_id}).")
         |> assign_domains(Monitor.list_domains())}

      {:error, :remote_domain_not_found} ->
        {:noreply, put_flash(socket, :error, "Domain tidak ditemukan di SFLINK.")}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, "Gagal hapus domain: #{inspect(reason)}")}
    end
  end

  def handle_event("refresh_remote_domains", _params, socket) do
    {:noreply,
     socket
     |> assign(:status_clock, DateTime.utc_now())
     |> assign_remote_domains()
     |> live_check_all_remote_domains()
     |> assign_next_refresh_seconds()}
  end

  def handle_event("sync_remote_domains", _params, socket) do
    case Monitor.sync_remote_domains_to_local() do
      {:ok, %{synced: count}} ->
        {:noreply,
         socket
         |> put_flash(:info, "Sync selesai. #{count} domain dari SFLINK diproses.")
         |> assign_domains(Monitor.list_domains())
         |> assign_remote_domains()}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, "Sync domain gagal: #{format_reason(reason)}")}
    end
  end

  def handle_event("search_domain_list", %{"domain_search" => %{"q" => q}}, socket) do
    {:noreply, assign(socket, :list_domain_query, String.trim(q || ""))}
  end

  def handle_event("delete_remote_domain", %{"id" => id} = params, socket) do
    profile_id_param = Map.get(params, "profile_id")

    with {remote_id, _} <- Integer.parse(id),
         {:ok, _result} <- delete_remote_domain_with_profile(remote_id, profile_id_param) do
      {:noreply,
       socket
       |> put_flash(:info, "Domain remote id #{remote_id} berhasil dihapus.")
       |> assign_domains(Monitor.list_domains())
       |> assign_remote_domains()}
    else
      {:error, reason} ->
        {:noreply, put_flash(socket, :error, "Gagal hapus domain: #{format_reason(reason)}")}

      _ ->
        {:noreply, put_flash(socket, :error, "ID domain tidak valid.")}
    end
  end

  def handle_event("live_check_remote_domain", %{"id" => id} = params, socket) do
    profile_id_param = Map.get(params, "profile_id")
    row_key = Map.get(params, "key", id)

    with {remote_id, _} <- Integer.parse(id),
         {:ok, result} <- live_check_remote_domain_with_profile(remote_id, profile_id_param) do
      statuses = Map.put(socket.assigns.remote_statuses, row_key, result.status)

      {:noreply,
       socket
       |> assign(:remote_statuses, statuses)
       |> put_flash(:info, "Live status domain id #{remote_id}: #{result.status}")}
    else
      _ ->
        {:noreply, put_flash(socket, :error, "Live check gagal untuk domain id #{id}.")}
    end
  end

  def handle_event("save_settings", %{"settings" => settings}, socket) do
    normalized =
      settings
      |> Map.put("sflink_base_url", "https://app.sflink.id")
      |> Map.put_new("telegram_notifications_enabled", "false")
      |> Map.put_new("telegram_group_notifications_enabled", "false")
      |> Map.put_new("telegram_private_notifications_enabled", "false")
      |> Map.update!("telegram_notifications_enabled", fn
        "true" -> "true"
        _ -> "false"
      end)
      |> Map.update!("telegram_group_notifications_enabled", fn
        "true" -> "true"
        _ -> "false"
      end)
      |> Map.update!("telegram_private_notifications_enabled", fn
        "true" -> "true"
        _ -> "false"
      end)
      |> Map.update("telegram_bot_token", "", &String.trim(to_string(&1)))
      |> Map.update("telegram_group_chat_id", "", &String.trim(to_string(&1)))
      |> Map.update("telegram_private_chat_id", "", &String.trim(to_string(&1)))

    Monitor.upsert_settings(normalized)

    updated_settings = Monitor.list_settings()
    info_message =
      if socket.assigns.current_page == :telegram,
        do: "Pengaturan Telegram berhasil disimpan.",
        else: "API Token berhasil tersimpan."

    socket =
      socket
      |> put_flash(:info, info_message)
      |> assign(:settings, updated_settings)
      |> assign(:settings_form, to_form(updated_settings, as: :settings))

    socket =
      if socket.assigns.current_page == :profile do
        socket
        |> assign_sflink_profile()
        |> assign(:sflink_profiles, Monitor.list_sflink_profiles())
      else
        socket
      end

    {:noreply, socket}
  end

  def handle_event("clear_sflink_token", _params, socket) do
    case Monitor.clear_active_sflink_token() do
      {:ok, _} ->
        settings = Monitor.list_settings()

        {:noreply,
         socket
         |> put_flash(:info, "SFLINK API token berhasil dihapus.")
         |> assign(:settings, settings)
         |> assign(:settings_form, to_form(settings, as: :settings))
         |> assign(:sflink_profiles, Monitor.list_sflink_profiles())
         |> assign(:sflink_profile, nil)}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, "Gagal hapus token: #{format_reason(reason)}")}
    end
  end

  def handle_event("add_sflink_profile", %{"sflink_profile" => params}, socket) do
    case Monitor.create_sflink_profile(params) do
      {:ok, _profile} ->
        settings = Monitor.list_settings()

        {:noreply,
         socket
         |> put_flash(:info, "Profile SFLINK berhasil ditambahkan.")
         |> assign(:settings, settings)
         |> assign(:settings_form, to_form(settings, as: :settings))
         |> assign(:sflink_profiles, Monitor.list_sflink_profiles())
         |> assign_sflink_profile()
         |> assign(:sflink_profile_form, to_form(%{"name" => "", "api_token" => ""}, as: :sflink_profile))}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply,
         socket
         |> put_flash(:error, "Gagal menambahkan profile SFLINK.")
         |> assign(:sflink_profile_form, to_form(changeset, as: :sflink_profile))}

      {:error, :token_limit} ->
        {:noreply,
         socket
         |> put_flash(:error, "Maksimal 10 profile SFLINK per user. Hapus profile lama untuk menambah profile baru.")}

      {:error, _reason} ->
        {:noreply, put_flash(socket, :error, "ERROR 911 SILAHKAN HUBUNGI RAKA")}
    end
  end

  def handle_event("activate_sflink_profile", %{"id" => id}, socket) do
    with {profile_id, _} <- Integer.parse(id),
         {:ok, _} <- Monitor.activate_sflink_profile(profile_id) do
      settings = Monitor.list_settings()

      {:noreply,
       socket
       |> put_flash(:info, "Profile SFLINK berhasil diaktifkan.")
       |> assign(:settings, settings)
       |> assign(:settings_form, to_form(settings, as: :settings))
       |> assign(:sflink_profiles, Monitor.list_sflink_profiles())
       |> assign_sflink_profile()}
    else
      {:error, reason} ->
        {:noreply, put_flash(socket, :error, "Gagal aktivasi profile: #{format_reason(reason)}")}

      _ ->
        {:noreply, put_flash(socket, :error, "ID profile tidak valid.")}
    end
  end

  def handle_event("delete_sflink_profile", %{"id" => id}, socket) do
    with {profile_id, _} <- Integer.parse(id),
         {:ok, _} <- Monitor.delete_sflink_profile(profile_id) do
      settings = Monitor.list_settings()

      {:noreply,
       socket
       |> put_flash(:info, "Profile SFLINK berhasil dihapus.")
       |> assign(:settings, settings)
       |> assign(:settings_form, to_form(settings, as: :settings))
       |> assign(:sflink_profiles, Monitor.list_sflink_profiles())
       |> assign_sflink_profile()}
    else
      {:error, reason} ->
        {:noreply, put_flash(socket, :error, "Gagal hapus profile: #{format_reason(reason)}")}

      _ ->
        {:noreply, put_flash(socket, :error, "ID profile tidak valid.")}
    end
  end

  def handle_event("run_checker_now", _params, socket) do
    case ElixirNawalaDK168.Workers.CheckerCycleWorker.enqueue() do
      {:ok, _job} ->
        {:noreply, put_flash(socket, :info, "Checker cycle berhasil di-queue.")}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Gagal menjalankan checker cycle.")}
    end
  end

  def handle_event("test_group", _params, socket) do
    msg = socket.assigns.test_message
    reply = if Notifier.send_test_message(:group, msg) == :ok, do: {:info, "Test message ke group terkirim."}, else: {:error, "Gagal kirim test message ke group."}
    {:noreply, put_flash(socket, elem(reply, 0), elem(reply, 1))}
  end

  def handle_event("test_private", _params, socket) do
    msg = socket.assigns.test_message
    reply = if Notifier.send_test_message(:private, msg) == :ok, do: {:info, "Test message ke private chat terkirim."}, else: {:error, "Gagal kirim test message ke private chat."}
    {:noreply, put_flash(socket, elem(reply, 0), elem(reply, 1))}
  end

  def handle_event("toggle_sidebar_collapse", _params, socket) do
    {:noreply, assign(socket, :sidebar_collapsed, !socket.assigns.sidebar_collapsed)}
  end

  def handle_event("toggle_sidebar_mobile", _params, socket) do
    {:noreply, assign(socket, :sidebar_open, !socket.assigns.sidebar_open)}
  end

  def handle_event("close_sidebar_mobile", _params, socket) do
    {:noreply, assign(socket, :sidebar_open, false)}
  end

  def handle_event("toggle_domain_menu", _params, socket) do
    {:noreply, assign(socket, :domain_menu_open, !socket.assigns.domain_menu_open)}
  end

  def handle_event("toggle_admin_menu", _params, socket) do
    {:noreply, assign(socket, :admin_menu_open, !socket.assigns.admin_menu_open)}
  end

  @impl true
  def handle_info({:domain_updated, _domain}, socket) do
    {:noreply, assign_domains(socket, Monitor.list_domains())}
  end

  @impl true
  def handle_info({:checker_cycle_finished, summary}, socket) do
    {:noreply, assign(socket, :last_cycle_info, summary)}
  end

  @impl true
  def handle_info(:status_tick, socket) do
    now = DateTime.utc_now()
    seconds = max((socket.assigns.next_refresh_seconds || 1) - 1, 0)

    socket =
      socket
      |> assign(:status_clock, now)
      |> assign(:next_refresh_seconds, seconds)

    socket =
      if socket.assigns.current_page == :status_domain and seconds == 0 do
        socket
        |> assign_remote_domains(false)
        |> live_check_all_remote_domains()
        |> assign_next_refresh_seconds()
      else
        socket
      end

    {:noreply, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <section class={["admin-shell", @sidebar_collapsed && "sidebar-collapsed", @sidebar_open && "sidebar-open"]}>
      <header class="admin-topbar">
        <div class="topbar-left">
          <button type="button" class="sidebar-toggle-btn" phx-click="toggle_sidebar_mobile" aria-label="Toggle sidebar">
            <.nav_icon name="domain" />
          </button>
          <span class="phoenix-mark">
            <.nav_icon name="phoenix" />
          </span>
          <span class="phoenix-word">Elixir Nawala</span>
        </div>
        <div class="topbar-right">
          <button type="button" class="icon-btn icon-btn-notify" aria-label="Notifications">
            <.nav_icon name="bell" />
          </button>
          <span class="avatar-chip">{String.first(@current_admin.email) |> String.upcase()}</span>
          <.link href="/admin/logout" method="delete" class="ghost-btn">Logout</.link>
        </div>
      </header>

      <aside class="admin-sidebar">
        <nav class="sidebar-nav">
          <.link class={menu_class(@current_page == :home)} href="/admin/home">
            <span class="menu-arrow"></span>
            <span class="menu-icon">
              <.nav_icon name="home" />
            </span>
            <span class="menu-label">Home</span>
          </.link>

          <p class="menu-group">APPS</p>

          <div class={["menu-expand", @domain_menu_open && "open"]} data-pop-title="Domain">
            <button type="button" class={menu_class(@current_page in [:add_domain, :list_domain, :status_domain])} phx-click="toggle_domain_menu">
              <span class="menu-arrow"></span>
              <span class="menu-icon">
                <.nav_icon name="domain" />
              </span>
              <span class="menu-label">Domain</span>
            </button>
            <div class="submenu-pop">
              <p class="submenu-pop-title">Domain</p>
              <.link class={submenu_class(@current_page == :add_domain)} href="/admin/domain/add">Add Domain</.link>
              <.link class={submenu_class(@current_page == :status_domain)} href="/admin/domain/status">Domain Status</.link>
              <.link class={submenu_class(@current_page == :list_domain)} href="/admin/domain/list">List Domain</.link>
            </div>
          </div>

          <.link class={menu_class(@current_page == :telegram)} href="/admin/telegram">
            <span class="menu-arrow blank"></span>
            <span class="menu-icon">
              <.nav_icon name="telegram" />
            </span>
            <span class="menu-label">Telegram</span>
          </.link>

          <div class={["menu-expand", @admin_menu_open && "open"]} data-pop-title="Admin">
            <button type="button" class={menu_class(@current_page == :profile)} phx-click="toggle_admin_menu">
              <span class="menu-arrow"></span>
              <span class="menu-icon">
                <.nav_icon name="admin" />
              </span>
              <span class="menu-label">Admin</span>
            </button>
            <div class="submenu-pop">
              <p class="submenu-pop-title">Admin</p>
              <.link class={submenu_class(@current_page == :profile)} href="/admin/profile">Profile</.link>
              <a class="submenu-item" href="#admin-manage">Admin</a>
            </div>
          </div>
        </nav>

        <button type="button" class="sidebar-footer" phx-click="toggle_sidebar_collapse">
          <span class="menu-icon">
            <.nav_icon name={if @sidebar_collapsed, do: "expand", else: "collapse"} />
          </span>
          <span>Collapsed View</span>
        </button>
      </aside>

      <button :if={@sidebar_open} type="button" class="sidebar-backdrop" phx-click="close_sidebar_mobile" aria-label="Close sidebar"></button>

      <div class="admin-main">
        <div class="admin-content">
          <%= if @current_page == :home do %>
            <section id="overview" class="maintenance-card maintenance-card-centered">
              <h1 class="admin-title beta-title">
                <span class="beta-main">ELIXIR NAWALA</span>
                <small class="beta-sub">(Version 1)</small>
              </h1>
              <p class="admin-subtitle">Wait next maintenance for using:</p>
              <ol class="admin-subtitle" style="margin-top: 0.6rem; padding-left: 1.2rem; line-height: 1.7;">
                <li>Notification Web UI.</li>
                <li>Admin Panel.</li>
                <li>Application for mobile phone.</li>
                <li>Fixing Telegram Bot issued (support private chat, not spamming group chat).</li>
              </ol>
              <p class="maintenance-footnote">Contribute to SEO_Setengah_Waras.</p>
            </section>
          <% end %>

          <%= if @current_page == :add_domain do %>
            <section id="domain-add" class="card-dark add-domain-card">
              <div class="add-domain-grid">
                <article class="add-domain-hero">
                  <h2>Tambah Domain</h2>
                  <p class="admin-subtitle">
                    Daftarkan domain untuk monitoring TrustPositif via SFLINK dan sinkronisasi status secara realtime.
                  </p>

                  <div class="add-domain-points">
                    <div class="add-domain-point">
                      <span class="point-icon"><.status_icon name="shield" /></span>
                      <div>
                        <strong>Keamanan Aktif</strong>
                        <p>Status domain dipantau untuk deteksi BLOCKED/TRUSTED.</p>
                      </div>
                    </div>
                    <div class="add-domain-point">
                      <span class="point-icon"><.status_icon name="link" /></span>
                      <div>
                        <strong>Sinkron SFLINK</strong>
                        <p>Domain baru langsung dikirim ke endpoint API SFLINK.</p>
                      </div>
                    </div>
                    <div class="add-domain-point">
                      <span class="point-icon"><.status_icon name="clock" /></span>
                      <div>
                        <strong>Auto Monitoring</strong>
                        <p>Data domain otomatis tersedia di List Domain dan Domain Status.</p>
                      </div>
                    </div>
                  </div>
                </article>

                <article class="add-domain-form-card">
                  <h3>Form Tambah Domain</h3>
                  <.form for={@domain_form} action="/admin/domains" method="post" phx-submit="create_domain">
                    <label for="add-domain-profile">User Profile</label>
                    <select
                      id="add-domain-profile"
                      name="domain[profile_id]"
                      class="add-domain-profile-select"
                      required
                      disabled={@add_domain_profiles == []}
                    >
                      <option value="">Pilih user profile</option>
                      <option
                        :for={profile <- @add_domain_profiles}
                        value={profile.id}
                        selected={to_string(@domain_form[:profile_id].value) == to_string(profile.id)}
                      >
                        {profile_option_label(profile)}
                      </option>
                    </select>
                    <p :if={add_domain_quota_label(@add_domain_profiles, @domain_form[:profile_id].value)} class="add-domain-profile-badge">
                      {add_domain_quota_label(@add_domain_profiles, @domain_form[:profile_id].value)}
                    </p>

                    <label for="add-domain-input">Nama Domain</label>
                    <input
                      id="add-domain-input"
                      type="text"
                      name="domain[name]"
                      value={@domain_form[:name].value}
                      placeholder="contoh: example.com"
                      autocomplete="off"
                      disabled={@add_domain_profiles == []}
                      required
                    />
                    <p class="form-hint">Gunakan format domain tanpa http/https untuk validasi yang lebih akurat.</p>
                    <p :if={@add_domain_profiles == []} class="form-hint">
                      Tidak ada user profile dengan kuota domain tersedia.
                    </p>
                    <div class="actions">
                      <button type="submit" disabled={@add_domain_profiles == []}>
                        <.status_icon name="check" /> Tambahkan Domain
                      </button>
                    </div>
                  </.form>
                </article>
              </div>
            </section>
          <% end %>

          <%= if @current_page == :status_domain do %>
            <section id="domain-status" class="domain-status-card">
              <div class="domain-status-head">
                <h2>
                  <span class="head-icon"><.status_icon name="shield" /></span>
                  Domain Status
                </h2>
                <button type="button" class="refresh-btn" phx-click="refresh_remote_domains">Refresh</button>
              </div>

              <div class="system-banner">
                <span class="system-dot"></span>
                <div>
                  <p class="system-line"><strong>System Status:</strong> Active</p>
                  <p class="system-sub">
                    Last updated: {jakarta_time(@status_clock)} | Next refresh: {countdown_label_seconds(@next_refresh_seconds)}
                  </p>
                </div>
              </div>

              <div class="status-grid-head">
                <span><.status_icon name="globe" /> DOMAIN</span>
                <span><.status_icon name="pulse" /> MONITOR STATUS</span>
                <span>LAST CHECK</span>
                <span><.status_icon name="gear" /> INTERVAL</span>
                <span><.status_icon name="shield" /> CHECK STATUS</span>
                <span><.status_icon name="clock" /> NEXT CHECK</span>
                <span><.status_icon name="link" /> LIVE CHECK</span>
              </div>

              <div class="status-grid-row" :for={rd <- @remote_domains}>
                <div class="domain-col">
                  <div class="domain-avatar"><.status_icon name="globe" /></div>
                  <div>
                    <p class="domain-name">{rd.domain}</p>
                    <p class="domain-meta">
                      Added {format_added_date(rd.created_at)}
                    </p>
                  </div>
                </div>

                <div>
                  <span class={"badge " <> monitor_status_class(rd.status)}>
                    <.status_icon name="check" /> {monitor_status_label(rd.status)}
                  </span>
                </div>

                <div>
                  <p class="mono-line">{format_api_datetime(rd.last_checked, "%d %b %H:%M")}</p>
                  <p class="domain-meta">{relative_last_check(rd.last_checked, @status_clock)}</p>
                </div>

                <div>
                  <span class="badge badge-blue"><.status_icon name="clock" /> {interval_label(rd.check_interval_minutes, @settings["checker_interval_seconds"])}</span>
                </div>

                <div>
                  <span class={"badge " <> check_status_class(rd, @remote_statuses)}>
                    <.status_icon name="shield" /> {check_status_text(rd, @remote_statuses)}
                  </span>
                </div>

                <div>
                  <p class="mono-line">{next_check_time_from_api(rd, @status_clock)}</p>
                  <p class="domain-meta">{countdown_label(rd, @status_clock)}</p>
                </div>

                <div>
                  <button
                    class="inline-action"
                    phx-click="live_check_remote_domain"
                    phx-value-id={rd.id}
                    phx-value-profile_id={rd.source_profile_id}
                    phx-value-key={remote_domain_key(rd)}
                  >
                    <.status_icon name="link" /> Live Check
                  </button>
                </div>
              </div>

              <div class="status-note">
                <strong>Auto Check Information</strong>
                <p>
                  Domains are automatically checked based on their individual interval settings.
                  TrustPositif status is checked on page load and displayed next to domain name.
                </p>
              </div>
            </section>
          <% end %>

          <%= if @current_page == :list_domain do %>
            <section id="domain-list" class="card-dark">
              <div class="list-domain-head">
                <h2 class="list-domain-title">List Domain</h2>
                <.form for={to_form(%{"q" => @list_domain_query}, as: :domain_search)} phx-change="search_domain_list" class="list-domain-search-form">
                  <input
                    type="text"
                    name="domain_search[q]"
                    value={@list_domain_query}
                    placeholder="Cari domain..."
                    class="list-domain-search"
                    phx-debounce="250"
                    autocomplete="off"
                  />
                </.form>
              </div>
              <div class="table-wrap">
                <table class="domain-list-table">
                  <thead>
                    <tr>
                      <th>Remote ID</th>
                      <th>Profile</th>
                      <th>Domain</th>
                      <th>Status</th>
                      <th class="action-col">Action</th>
                    </tr>
                  </thead>
                  <tbody>
                    <tr :for={rd <- filtered_remote_domains(@remote_domains, @list_domain_query)}>
                      <td>{rd.id}</td>
                      <td>{rd.source_profile_name || "Default"}</td>
                      <td>{rd.domain}</td>
                      <td>
                        <span class={"badge " <> check_status_class(rd, @remote_statuses)}>
                          <.status_icon name="shield" /> {check_status_text(rd, @remote_statuses)}
                        </span>
                      </td>
                      <td class="action-col">
                        <button phx-click="delete_remote_domain" phx-value-id={rd.id} phx-value-profile_id={rd.source_profile_id}>Delete</button>
                      </td>
                    </tr>
                    <tr :if={filtered_remote_domains(@remote_domains, @list_domain_query) == []}>
                      <td colspan="5">Domain tidak ditemukan.</td>
                    </tr>
                  </tbody>
                </table>
              </div>
            </section>
          <% end %>

          <%= if @current_page == :telegram do %>
            <section id="telegram-settings" class="card-dark">
              <div class="actions" style="margin-top: 0;">
                <h2 style="margin: 0;">Telegram Bot</h2>
              </div>

              <div class="admin-grid profile-grid" style="margin-top: 0.85rem;">
                <article class="card-dark">
                  <h3 style="margin: 0 0 0.5rem 0; color: #f5f9ff;">Konfigurasi</h3>
                  <.form for={@settings_form} phx-submit="save_settings">
                    <label>Telegram Bot Token</label>
                    <input
                      type="password"
                      name="settings[telegram_bot_token]"
                      value={@settings["telegram_bot_token"]}
                      placeholder="123456789:AA..."
                      autocomplete="off"
                    />

                    <label>Group Chat ID</label>
                    <input
                      type="text"
                      name="settings[telegram_group_chat_id]"
                      value={@settings["telegram_group_chat_id"]}
                      placeholder="-100xxxxxxxxxx"
                      autocomplete="off"
                    />

                    <label>Private Chat ID</label>
                    <input
                      type="text"
                      name="settings[telegram_private_chat_id]"
                      value={@settings["telegram_private_chat_id"]}
                      placeholder="123456789"
                      autocomplete="off"
                    />

                    <label class="checkbox-label">
                      <input type="checkbox" name="settings[telegram_notifications_enabled]" value="true" checked={@settings["telegram_notifications_enabled"] == "true"} />
                      Aktifkan Notifikasi Telegram
                    </label>

                    <label class="checkbox-label">
                      <input type="checkbox" name="settings[telegram_group_notifications_enabled]" value="true" checked={@settings["telegram_group_notifications_enabled"] == "true"} />
                      Aktifkan Notifikasi Group
                    </label>

                    <label class="checkbox-label">
                      <input type="checkbox" name="settings[telegram_private_notifications_enabled]" value="true" checked={@settings["telegram_private_notifications_enabled"] == "true"} />
                      Aktifkan Notifikasi Private
                    </label>

                    <div class="actions">
                      <button type="submit">Simpan Telegram</button>
                    </div>
                  </.form>
                </article>

                <article class="card-dark">
                  <h3 style="margin: 0 0 0.5rem 0; color: #f5f9ff;">Tes Notifikasi</h3>
                  <p class="admin-subtitle">Gunakan tombol di bawah untuk test kirim pesan ke channel Telegram.</p>
                  <div class="actions">
                    <button type="button" phx-click="test_group">Test Group</button>
                    <button type="button" phx-click="test_private">Test Private</button>
                  </div>
                  <p class="admin-subtitle" style="margin-top: 0.9rem;">
                    Notifikasi ringkasan dikirim otomatis setiap 5 menit berisi seluruh domain + waktu check.
                  </p>
                  <p class="admin-subtitle" style="margin-top: 0.4rem;">
                    Notifikasi live dikirim saat domain terdeteksi BLOCKED atau ERROR.
                  </p>
                </article>
              </div>
            </section>
          <% end %>

          <%= if @current_page == :profile do %>
            <section id="profile-overview" class="card-dark">
              <div class="actions" style="margin-top: 0;">
                <h2 style="margin: 0;">Profile Overview</h2>
              </div>

              <%= if @sflink_profiles == [] do %>
                <div class="admin-grid profile-grid" style="margin-top: 0.85rem;">
                  <article class="card-dark profile-user-blur">
                    <h3 style="margin: 0 0 0.5rem 0; color: #f5f9ff;">User Profile</h3>
                    <p class="admin-subtitle">Diperlukan minimal 1 SFLINK API Token untuk menjalankan program, silahkan tambahkan API Token.</p>
                  </article>
                  <article class="card-dark">
                    <h3 style="margin: 0 0 0.5rem 0; color: #f5f9ff;">SFLINK API Token</h3>
                    <p class="admin-subtitle">Belum ada token tersimpan.</p>
                  </article>
                </div>
              <% else %>
                <div :for={profile <- @sflink_profiles} class="admin-grid profile-grid" style="margin-top: 0.85rem;">
                  <article class="card-dark">
                    <h3 style="margin: 0 0 0.5rem 0; color: #f5f9ff;">User Profile</h3>
                    <table>
                      <tbody>
                        <tr>
                          <th>Username</th>
                          <td>{profile.name}</td>
                        </tr>
                        <tr>
                          <th>Email</th>
                          <td>{profile.email || "-"}</td>
                        </tr>
                        <tr>
                          <th>Status</th>
                          <td>
                            <span class={if profile.active, do: "badge badge-green", else: "badge badge-gray"}>
                              {if profile.active, do: "Active", else: "Inactive"}
                            </span>
                          </td>
                        </tr>
                      </tbody>
                    </table>
                  </article>
                  <article class="card-dark">
                    <h3 style="margin: 0 0 0.5rem 0; color: #f5f9ff;">SFLINK API Token</h3>
                    <label>API Token</label>
                    <input
                      type="password"
                      value={profile.api_token}
                      placeholder="sf_xxxxx"
                      autocomplete="off"
                      readonly
                    />

                    <div class="actions">
                      <button type="button" phx-click="activate_sflink_profile" phx-value-id={profile.id}>Save API Token</button>
                      <button type="button" phx-click="delete_sflink_profile" phx-value-id={profile.id}>Hapus API Token</button>
                    </div>
                  </article>
                </div>
              <% end %>
            </section>

            <section id="profile-management" class="card-dark" style="margin-top: 1rem;">
              <div class="actions" style="margin-top: 0;">
                <h2 style="margin: 0;">Tambah Profile</h2>
                <span class="badge badge-blue">{length(@sflink_profiles)}/{@max_sflink_profiles}</span>
              </div>

              <div class="admin-grid profile-grid" style="margin-top: 0.85rem;">
                <article class="card-dark profile-user-blur profile-placeholder-error">
                  <h3 style="margin: 0 0 0.5rem 0; color: #f5f9ff;">User Profile</h3>
                  <div class="placeholder-center">
                    <p class="admin-subtitle placeholder-message" style="margin: 0;">Silahkan tambahkan profile dengan cara memasukan SFLINK API Token.</p>
                  </div>
                </article>

                <article class="card-dark">
                  <h3 style="margin: 0 0 0.5rem 0; color: #f5f9ff;">SFLINK API Token</h3>
                  <.form for={@sflink_profile_form} phx-submit="add_sflink_profile">
                    <label>SFLINK API Token</label>
                    <input
                      type="password"
                      name="sflink_profile[api_token]"
                      value={@sflink_profile_form[:api_token].value}
                      placeholder="sf_xxxxx"
                      autocomplete="off"
                      disabled={length(@sflink_profiles) >= @max_sflink_profiles}
                      required
                    />
                    <p :if={length(@sflink_profiles) >= @max_sflink_profiles} class="admin-subtitle" style="margin: 0.5rem 0 0;">
                      Batas maksimal 10 profile sudah tercapai.
                    </p>

                    <div class="actions">
                      <button type="submit" disabled={length(@sflink_profiles) >= @max_sflink_profiles}>Tambah Profile</button>
                    </div>
                  </.form>
                </article>
              </div>
            </section>
          <% end %>
        </div>
      </div>
    </section>
    """
  end

  defp assign_domains(socket, domains) do
    assign(socket, domains: domains, stats: compute_stats(domains))
  end

  defp compute_stats(domains) do
    %{
      active: Enum.count(domains, & &1.active),
      down: Enum.count(domains, &(&1.last_status in ["down", "error"])),
      nawala: Enum.count(domains, &(&1.last_status == "nawala"))
    }
  end

  defp assign_remote_domains(socket, show_error \\ true) do
    case Monitor.list_remote_domains() do
      {:ok, domains} ->
        assign(socket, :remote_domains, domains)

      {:error, reason} ->
        socket
        |> assign(:remote_domains, [])
        |> maybe_flash_error(show_error, "Gagal load list domain dari SFLINK: #{format_reason(reason)}")

      _ ->
        socket
        |> assign(:remote_domains, [])
        |> maybe_flash_error(show_error, "Gagal load list domain dari SFLINK.")
    end
  end

  defp page_from_action(:add_domain), do: :add_domain
  defp page_from_action(:list_domain), do: :list_domain
  defp page_from_action(:status_domain), do: :status_domain
  defp page_from_action(:telegram), do: :telegram
  defp page_from_action(:profile), do: :profile
  defp page_from_action(_), do: :home

  defp page_title(:add_domain), do: "Add Domain"
  defp page_title(:list_domain), do: "List Domain"
  defp page_title(:status_domain), do: "Domain Status"
  defp page_title(:telegram), do: "Telegram"
  defp page_title(:profile), do: "Profile"
  defp page_title(:home), do: "Admin Home"

  defp menu_class(true), do: "menu-item active"
  defp menu_class(false), do: "menu-item"

  defp submenu_class(true), do: "submenu-item active"
  defp submenu_class(false), do: "submenu-item"

  attr :name, :string, required: true
  defp nav_icon(assigns) do
    ~H"""
    <%= case @name do %>
      <% "phoenix" -> %>
        <svg viewBox="0 0 24 24" fill="none" aria-hidden="true">
          <path d="M5.7 20.6V11a6.3 6.3 0 0 1 12.6 0v9.6" fill="currentColor"/>
          <path d="M5.7 20.6c.8 0 1.4-.6 2-1.2.5.6 1.1 1.2 1.9 1.2s1.5-.6 2-1.2c.5.6 1.1 1.2 2 1.2s1.5-.6 2-1.2c.5.6 1.1 1.2 1.9 1.2" stroke="#0b1324" stroke-width="1.25" stroke-linecap="round" stroke-linejoin="round"/>
          <path d="M8.2 8.8h2.6M9.5 7.5v2.6" stroke="#0b1324" stroke-width="1.5" stroke-linecap="round"/>
          <path d="m13.7 9.4 2.9-1.6-2.9-1.6M13.7 9.4l2.9 1.6" stroke="#0b1324" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"/>
          <path d="M8 13.7h7.9" stroke="#0b1324" stroke-width="1.5" stroke-linecap="round"/>
          <path d="M18.3 5.7c.9.5 1.5 1.4 1.6 2.5M16.8 4.5c.4 0 .8.1 1.2.2" stroke="currentColor" stroke-width="1.2" stroke-linecap="round" opacity="0.6"/>
        </svg>
      <% "moon" -> %>
        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">
          <path d="M21 12.8A9 9 0 1 1 11.2 3a7 7 0 1 0 9.8 9.8z"/>
        </svg>
      <% "bell" -> %>
        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">
          <path d="M15 17H5.5l1.4-1.4A2 2 0 0 0 7.5 14V11a4.5 4.5 0 1 1 9 0v3a2 2 0 0 0 .6 1.4L18.5 17z"/>
          <path d="M10 19a2 2 0 0 0 4 0"/>
        </svg>
      <% "grid" -> %>
        <svg viewBox="0 0 24 24" fill="currentColor" aria-hidden="true">
          <rect x="4" y="4" width="4" height="4" rx="1"></rect>
          <rect x="10" y="4" width="4" height="4" rx="1"></rect>
          <rect x="16" y="4" width="4" height="4" rx="1"></rect>
          <rect x="4" y="10" width="4" height="4" rx="1"></rect>
          <rect x="10" y="10" width="4" height="4" rx="1"></rect>
          <rect x="16" y="10" width="4" height="4" rx="1"></rect>
          <rect x="4" y="16" width="4" height="4" rx="1"></rect>
          <rect x="10" y="16" width="4" height="4" rx="1"></rect>
          <rect x="16" y="16" width="4" height="4" rx="1"></rect>
        </svg>
      <% "home" -> %>
        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">
          <path d="M3 10.5 12 3l9 7.5"/>
          <path d="M5.5 9.8V20h13V9.8"/>
          <path d="M10 20v-4h4v4"/>
        </svg>
      <% "domain" -> %>
        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">
          <circle cx="12" cy="12" r="8.5"/>
          <path d="M3.8 9h16.4M3.8 15h16.4M12 3.5c2.3 2.3 3.6 5.3 3.6 8.5S14.3 18.2 12 20.5M12 3.5C9.7 5.8 8.4 8.8 8.4 12S9.7 18.2 12 20.5"/>
        </svg>
      <% "telegram" -> %>
        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">
          <path d="m21 4-3.2 15.3c-.2 1-1.2 1.5-2.1 1.1L11 18l-2.4 2.2c-.6.6-1.7.2-1.8-.7L6 14 2.2 12c-.9-.5-.8-1.8.2-2.1L20 3.4c.7-.2 1.3.4 1.2 1.1z"/>
          <path d="m6.2 14 11.4-8.3"/>
        </svg>
      <% "admin" -> %>
        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">
          <circle cx="12" cy="8" r="3.2"/>
          <path d="M5 20c.9-3.2 3.7-5 7-5s6.1 1.8 7 5"/>
          <path d="M18.5 8.5v3M17 10h3"/>
        </svg>
      <% "collapse" -> %>
        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.9" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">
          <path d="M5.5 4.5v15"/>
          <path d="M18.5 12h-9"/>
          <path d="m12.5 8-4 4 4 4"/>
        </svg>
      <% "expand" -> %>
        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.9" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">
          <path d="M5.5 4.5v15"/>
          <path d="M9.5 12h9"/>
          <path d="m14.5 8 4 4-4 4"/>
        </svg>
      <% _ -> %>
        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" aria-hidden="true">
          <circle cx="12" cy="12" r="8"/>
        </svg>
    <% end %>
    """
  end

  defp format_reason(:missing_sflink_token), do: "ERROR DIRECTLY CALL 911 RAKA GANTENG"
  defp format_reason({:http_error, code, _message, _body}) when code in [401, 403],
    do: "ERROR DIRECTLY CALL 911 RAKA GANTENG"

  defp format_reason({:http_error, code, message, _body}), do: "HTTP #{code} - #{message}"
  defp format_reason({:sflink_error, message, _body}), do: message
  defp format_reason({:invalid_response, body}), do: "Invalid response: #{inspect(body)}"
  defp format_reason(reason), do: inspect(reason)

  defp sync_remote_domains(socket) do
    case Monitor.sync_remote_domains_to_local() do
      {:ok, _} -> socket
      _ -> socket
    end
  end

  defp checker_interval_label(nil), do: "5 min"

  defp checker_interval_label(seconds) when is_binary(seconds) do
    case Integer.parse(seconds) do
      {value, _} -> checker_interval_label(value)
      _ -> "5 min"
    end
  end

  defp checker_interval_label(seconds) when is_integer(seconds) and seconds >= 60 do
    minutes = div(seconds, 60)
    "#{minutes} min"
  end

  defp checker_interval_label(_), do: "5 min"

  attr :name, :string, required: true
  defp status_icon(assigns) do
    ~H"""
    <%= case @name do %>
      <% "shield" -> %>
        <svg viewBox="0 0 20 20" fill="none" stroke="currentColor" stroke-width="1.8"><path d="M10 2.2 4 4.5v4.8c0 3.5 2.3 6.8 6 8.5 3.7-1.7 6-5 6-8.5V4.5L10 2.2z"/></svg>
      <% "globe" -> %>
        <svg viewBox="0 0 20 20" fill="none" stroke="currentColor" stroke-width="1.8"><circle cx="10" cy="10" r="7"/><path d="M3 10h14M10 3c2 2 3 4.5 3 7s-1 5-3 7c-2-2-3-4.5-3-7s1-5 3-7"/></svg>
      <% "pulse" -> %>
        <svg viewBox="0 0 20 20" fill="none" stroke="currentColor" stroke-width="1.8"><path d="M2.5 10h4l1.5-3 2.5 6 1.5-3h5.5"/></svg>
      <% "gear" -> %>
        <svg viewBox="0 0 20 20" fill="none" stroke="currentColor" stroke-width="1.8"><circle cx="10" cy="10" r="2.5"/><path d="M10 2.5v2M10 15.5v2M2.5 10h2M15.5 10h2M4.6 4.6l1.4 1.4M14 14l1.4 1.4M15.4 4.6 14 6M6 14l-1.4 1.4"/></svg>
      <% "clock" -> %>
        <svg viewBox="0 0 20 20" fill="none" stroke="currentColor" stroke-width="1.8"><circle cx="10" cy="10" r="7"/><path d="M10 6.3v4l2.5 1.5"/></svg>
      <% "link" -> %>
        <svg viewBox="0 0 20 20" fill="none" stroke="currentColor" stroke-width="1.8"><path d="M8 12a3 3 0 0 1 0-4l2-2a3 3 0 1 1 4.2 4.2l-1 1"/><path d="M12 8a3 3 0 0 1 0 4l-2 2a3 3 0 1 1-4.2-4.2l1-1"/></svg>
      <% "check" -> %>
        <svg viewBox="0 0 20 20" fill="none" stroke="currentColor" stroke-width="1.8"><circle cx="10" cy="10" r="7"/><path d="m7 10.2 2 2.1 4-4"/></svg>
      <% _ -> %>
        <svg viewBox="0 0 20 20" fill="none" stroke="currentColor" stroke-width="1.8"><circle cx="10" cy="10" r="7"/></svg>
    <% end %>
    """
  end

  defp normalized_domain_status(rd, remote_statuses) do
    Map.get(remote_statuses, remote_domain_key(rd), rd.status || "unknown")
    |> to_string()
    |> String.downcase()
  end

  defp format_added_date(nil), do: "-"
  defp format_added_date(value) when is_binary(value) do
    case DateTime.from_iso8601(value) do
      {:ok, dt, _} -> Calendar.strftime(dt, "%d %b %Y")
      _ -> value
    end
  end

  defp parse_api_datetime(nil), do: nil

  defp parse_api_datetime(value) when is_binary(value) do
    iso = String.replace(value, " ", "T")

    case NaiveDateTime.from_iso8601(iso) do
      {:ok, ndt} -> DateTime.from_naive!(ndt, "Etc/UTC")
      _ -> nil
    end
  end

  defp format_api_datetime(value, format) do
    case parse_api_datetime(value) do
      %DateTime{} = dt -> Calendar.strftime(dt, format)
      _ -> "-"
    end
  end

  defp next_check_datetime(rd) do
    with %DateTime{} = dt <- parse_api_datetime(rd.last_checked),
         minutes when is_integer(minutes) <- rd.check_interval_minutes do
      DateTime.add(dt, minutes * 60, :second)
    else
      _ -> nil
    end
  end

  defp countdown_to_next_check(rd, now) do
    case next_check_datetime(rd) do
      %DateTime{} = dt ->
        sec = max(DateTime.diff(dt, api_now_for_calc(now), :second), 0)
        "#{String.pad_leading(Integer.to_string(div(sec, 60)), 2, "0")}:#{String.pad_leading(Integer.to_string(rem(sec, 60)), 2, "0")}"

      _ ->
        "00:00"
    end
  end

  defp next_check_time_from_api(rd, now) do
    case next_check_datetime(rd) do
      %DateTime{} = dt ->
        Calendar.strftime(dt, "%H:%M")

      _ ->
        Calendar.strftime(api_now_for_calc(now), "%H:%M")
    end
  end

  defp monitor_status_label(true), do: "Active"
  defp monitor_status_label("true"), do: "Active"
  defp monitor_status_label(_), do: "Inactive"

  defp monitor_status_class(status) when status in [true, "true"], do: "badge badge-green"
  defp monitor_status_class(_), do: "badge badge-gray"

  defp interval_label(minutes, _fallback) when is_integer(minutes) and minutes > 0, do: "#{minutes} min"
  defp interval_label(_, fallback), do: checker_interval_label(fallback)

  defp check_status_text(rd, remote_statuses) do
    status = normalized_domain_status(rd, remote_statuses)

    cond do
      status in ["up", "true", "trusted", "safe", "aman"] -> "TRUSTED"
      status in ["down", "false", "nawala", "blocked", "error", "diblokir"] -> "BLOCKED"
      true -> "UNKNOWN"
    end
  end

  defp check_status_class(rd, remote_statuses) do
    case check_status_text(rd, remote_statuses) do
      "TRUSTED" -> "badge-green"
      "BLOCKED" -> "badge-danger"
      _ -> "badge-gray"
    end
  end

  defp countdown_label(rd, now), do: "in #{countdown_to_next_check(rd, now)}"
  defp countdown_label_seconds(seconds) when is_integer(seconds), do: "in #{format_mm_ss(seconds)}"
  defp countdown_label_seconds(_), do: "in 00:00"

  defp relative_last_check(value, now) do
    case parse_api_datetime(value) do
      %DateTime{} = dt ->
        diff = max(DateTime.diff(api_now_for_calc(now), dt, :second), 0)

        cond do
          diff < 60 -> "Just now"
          diff < 3600 -> "#{div(diff, 60)} min ago"
          true -> "#{div(diff, 3600)} h ago"
        end

      _ ->
        "-"
    end
  end

  defp assign_next_refresh_seconds(socket) do
    seconds =
      socket.assigns.remote_domains
      |> Enum.map(&seconds_to_next_check(&1, socket.assigns.status_clock))
      |> Enum.reject(&is_nil/1)
      |> Enum.min(fn -> 20 end)
      |> max(1)

    assign(socket, :next_refresh_seconds, seconds)
  end

  defp seconds_to_next_check(rd, now) do
    case next_check_datetime(rd) do
      %DateTime{} = dt -> max(DateTime.diff(dt, api_now_for_calc(now), :second), 0)
      _ -> nil
    end
  end

  defp maybe_flash_error(socket, true, message), do: put_flash(socket, :error, message)
  defp maybe_flash_error(socket, false, _message), do: socket

  defp api_now_for_calc(%DateTime{} = now) do
    DateTime.add(now, @api_time_offset_seconds, :second)
  end

  defp jakarta_time(%DateTime{} = now) do
    now
    |> DateTime.add(@api_time_offset_seconds, :second)
    |> Calendar.strftime("%H:%M:%S")
  end

  defp live_check_all_remote_domains(socket) do
    statuses =
      Enum.reduce(socket.assigns.remote_domains, socket.assigns.remote_statuses, fn rd, acc ->
        case live_check_remote_domain_with_profile(rd.id, rd.source_profile_id) do
          {:ok, result} -> Map.put(acc, remote_domain_key(rd), result.status)
          _ -> acc
        end
      end)

    assign(socket, :remote_statuses, statuses)
  end

  defp format_mm_ss(total_seconds) do
    sec = max(total_seconds, 0)
    "#{String.pad_leading(Integer.to_string(div(sec, 60)), 2, "0")}:#{String.pad_leading(Integer.to_string(rem(sec, 60)), 2, "0")}"
  end

  defp remote_domain_key(rd) when is_map(rd) do
    Map.get(rd, :domain_key) || "#{Map.get(rd, :source_profile_id, "default")}:#{Map.get(rd, :id, "unknown")}"
  end

  defp live_check_remote_domain_with_profile(remote_id, nil),
    do: Monitor.live_check_remote_domain_status(remote_id)

  defp live_check_remote_domain_with_profile(remote_id, profile_id) when is_integer(profile_id),
    do: Monitor.live_check_remote_domain_status(remote_id, profile_id)

  defp live_check_remote_domain_with_profile(remote_id, profile_id) when is_binary(profile_id) do
    case Integer.parse(profile_id) do
      {parsed, _} -> Monitor.live_check_remote_domain_status(remote_id, parsed)
      _ -> Monitor.live_check_remote_domain_status(remote_id)
    end
  end

  defp delete_remote_domain_with_profile(remote_id, nil), do: Monitor.delete_remote_domain(remote_id)

  defp delete_remote_domain_with_profile(remote_id, profile_id) when is_integer(profile_id),
    do: Monitor.delete_remote_domain(remote_id, profile_id)

  defp delete_remote_domain_with_profile(remote_id, profile_id) when is_binary(profile_id) do
    case Integer.parse(profile_id) do
      {parsed, _} -> Monitor.delete_remote_domain(remote_id, parsed)
      _ -> Monitor.delete_remote_domain(remote_id)
    end
  end

  defp blank_token?(value) when is_binary(value), do: String.trim(value) == ""
  defp blank_token?(_), do: true

  defp mask_api_token(token) when is_binary(token) do
    trimmed = String.trim(token)

    cond do
      trimmed == "" ->
        "-"

      String.length(trimmed) <= 14 ->
        trimmed

      true ->
        "#{String.slice(trimmed, 0, 10)}...#{String.slice(trimmed, -4, 4)}"
    end
  end

  defp mask_api_token(_), do: "-"

  defp assign_sflink_profile(socket) do
    profiles = Monitor.list_sflink_profiles()

    socket
    |> assign(:sflink_profiles, profiles)
    |> assign(:sflink_profile, List.last(profiles))
  end

  defp profile_field(map, keys) when is_map(map) do
    keys
    |> Enum.find_value("-", fn key ->
      value = map[key]
      if is_nil(value) or value == "", do: nil, else: to_string(value)
    end)
  end

  defp profile_field(_, _), do: "-"

  defp stat_field(map, keys) when is_map(map) do
    keys
    |> Enum.find_value("0", fn key ->
      value = map[key]

      cond do
        is_integer(value) -> Integer.to_string(value)
        is_float(value) -> :erlang.float_to_binary(value, decimals: 0)
        is_binary(value) and value != "" -> value
        true -> nil
      end
    end)
  end

  defp stat_field(_, _), do: "0"

  defp nested_field(map, keys, default) when is_map(map) and is_list(keys) do
    case get_in(map, keys) do
      nil -> default
      value when is_binary(value) -> value
      value when is_integer(value) -> Integer.to_string(value)
      value when is_float(value) -> :erlang.float_to_binary(value, decimals: 0)
      value -> to_string(value)
    end
  end

  defp nested_field(_, _, default), do: default

  defp filtered_remote_domains(remote_domains, query) do
    q = normalize_search(query)

    if q == "" do
      remote_domains
    else
      remote_domains
      |> Enum.map(fn rd ->
        {rd, domain_match_score(rd, q)}
      end)
      |> Enum.filter(fn {_rd, score} -> score > 0.0 end)
      |> Enum.sort_by(fn {rd, score} -> {-score, String.downcase(to_string(rd.domain || "")), rd.id || 0} end)
      |> Enum.map(fn {rd, _score} -> rd end)
    end
  end

  defp domain_match_score(rd, query) do
    domain = normalize_search(rd.domain)
    domain_core = normalize_search(strip_tld(domain))
    query_core = normalize_search(strip_tld(query))

    cond do
      domain == "" ->
        0.0

      domain == query ->
        5.0

      String.starts_with?(domain, query) ->
        4.0

      String.contains?(domain, query) ->
        3.0

      String.starts_with?(domain_core, query_core) and query_core != "" ->
        2.5

      String.contains?(domain_core, query_core) and query_core != "" ->
        2.0

      true ->
        similarity = max(String.jaro_distance(domain, query), String.jaro_distance(domain_core, query_core))

        if similarity >= 0.78 do
          similarity
        else
          0.0
        end
    end
  end

  defp strip_tld(value) when is_binary(value) do
    value
    |> String.split(".")
    |> List.first()
    |> Kernel.||("")
  end

  defp strip_tld(_), do: ""

  defp normalize_search(value) when is_binary(value) do
    value
    |> String.trim()
    |> String.downcase()
  end

  defp normalize_search(_), do: ""

  defp assign_add_domain_profiles(socket) do
    profiles = Monitor.list_add_domain_profiles()
    default_profile_id = default_add_domain_profile_id(profiles)
    current_profile_id = socket.assigns.domain_form[:profile_id].value |> to_string()

    profile_id =
      cond do
        current_profile_id != "" and
            Enum.any?(profiles, fn profile -> to_string(profile.id) == current_profile_id end) ->
          current_profile_id

        true ->
          default_profile_id
      end

    socket
    |> assign(:add_domain_profiles, profiles)
    |> assign(
      :domain_form,
      to_form(%{"name" => socket.assigns.domain_form[:name].value || "", "profile_id" => profile_id}, as: :domain)
    )
  end

  defp default_add_domain_profile_id([profile | _]), do: to_string(profile.id)
  defp default_add_domain_profile_id(_), do: ""

  defp profile_option_label(profile) when is_map(profile) do
    name = profile[:name] || "Profile"
    remaining = profile[:domains_remaining]
    limit = profile[:domains_limit]

    case {remaining, limit} do
      {r, l} when is_integer(r) and is_integer(l) -> "#{name} (sisa #{r}/#{l})"
      {r, _} when is_integer(r) -> "#{name} (sisa #{r})"
      _ -> name
    end
  end

  defp add_domain_quota_label(profiles, selected_profile_id) do
    selected =
      selected_profile_id
      |> to_string()
      |> String.trim()

    case Enum.find(profiles, fn profile -> to_string(profile.id) == selected end) do
      nil ->
        nil

      profile ->
        case {profile[:domains_remaining], profile[:domains_limit]} do
          {r, l} when is_integer(r) and is_integer(l) -> "Sisa kuota #{r} dari #{l} domain."
          {r, _} when is_integer(r) -> "Sisa kuota #{r} domain."
          _ -> "Kuota domain tersedia."
        end
    end
  end

end

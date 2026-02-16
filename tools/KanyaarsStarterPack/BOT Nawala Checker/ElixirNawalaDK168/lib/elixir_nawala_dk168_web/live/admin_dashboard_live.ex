defmodule ElixirNawalaDK168Web.AdminDashboardLive do
  use ElixirNawalaDK168Web, :live_view

  alias ElixirNawalaDK168.Monitor
  alias ElixirNawalaDK168.Shortlink
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

    shortlink_defaults = Shortlink.new_short_link_form_defaults(shortlink_available_domain_names(domains, []))

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
     |> assign(:shortlink_menu_open, false)
     |> assign(:admin_menu_open, false)
     |> assign(:shortlink_form, to_form(shortlink_defaults, as: :shortlink))
     |> assign(:shortlink_list, [])
     |> assign(:shortlink_query, "")
     |> assign(:shortlink_stats, %{})
     |> assign(:shortlink_recent_clicks, [])
     |> assign(:shortlink_rotator_query, "")
     |> assign(:shortlink_rotator_list, [])
     |> assign(:shortlink_rotator_links, [])
     |> assign(:rotator_fallback_domains, [])
     |> assign(:rotator_form, to_form(Shortlink.new_rotator_form_defaults(), as: :rotator))
     |> assign(:rotator_modal_open, false)
     |> assign(:rotator_modal_link, nil)
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
      |> assign(:shortlink_menu_open, page in [:shortlink_create, :shortlink_list, :shortlink_stats, :shortlink_rotator])
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

        :shortlink_create ->
          socket
          |> assign_remote_domains(false)
          |> assign(
            :shortlink_form,
            to_form(
              Shortlink.new_short_link_form_defaults(
                shortlink_available_domain_names(socket.assigns.domains, socket.assigns.remote_domains)
              ),
              as: :shortlink
            )
          )

        :shortlink_list ->
          socket
          |> assign_shortlink_list()

        :shortlink_stats ->
          socket
          |> assign_shortlink_stats()

        :shortlink_rotator ->
          socket
          |> sync_remote_domains()
          |> assign_domains(Monitor.list_domains())
          |> assign_remote_domains(false)
          |> live_check_all_remote_domains()
          |> assign_shortlink_rotator_data()
          |> assign(:rotator_form, to_form(Shortlink.new_rotator_form_defaults(), as: :rotator))

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
         |> put_flash(:error, "ERROR DIRECTLY CALL 911 RAKA GANTENG")
         |> assign(:domain_form, to_form(changeset, as: :domain))}

      {:error, :missing_profile_selection} ->
        {:noreply, put_flash(socket, :error, "ERROR DIRECTLY CALL 911 RAKA GANTENG")}

      {:error, :invalid_profile_selection} ->
        {:noreply, put_flash(socket, :error, "ERROR DIRECTLY CALL 911 RAKA GANTENG")}

      {:error, :inactive_profile} ->
        {:noreply, put_flash(socket, :error, "ERROR DIRECTLY CALL 911 RAKA GANTENG")}

      {:error, :profile_not_found} ->
        {:noreply, put_flash(socket, :error, "ERROR DIRECTLY CALL 911 RAKA GANTENG")}

      {:error, reason} ->
        _ = format_reason(reason)
        {:noreply, socket |> put_flash(:error, "ERROR DIRECTLY CALL 911 RAKA GANTENG")}
    end
  end

  def handle_event("toggle_domain", %{"id" => id}, socket) do
    with {:ok, domain_id} <- parse_id_param(id),
         {:ok, _domain} <- Monitor.toggle_domain(domain_id) do
      domains = Monitor.list_domains()
      {:noreply, socket |> put_flash(:info, "Status domain diperbarui.") |> assign_domains(domains)}
    else
      _ ->
        {:noreply, put_flash(socket, :error, "ERROR DIRECTLY CALL 911 RAKA GANTENG")}
    end
  end

  def handle_event("delete_domain", %{"id" => id}, socket) do
    with {:ok, domain_id} <- parse_id_param(id),
         {:ok, %{local_name: name, remote_id: remote_id}} <- Monitor.delete_domain_from_sflink(domain_id) do
      {:noreply,
       socket
       |> put_flash(:info, "Domain #{name} deleted (SFLINK id: #{remote_id}).")
       |> assign_domains(Monitor.list_domains())}
    else
      {:error, :remote_domain_not_found} ->
        {:noreply, put_flash(socket, :error, "ERROR DIRECTLY CALL 911 RAKA GANTENG")}

      _ ->
        {:noreply, put_flash(socket, :error, "ERROR DIRECTLY CALL 911 RAKA GANTENG")}
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

      {:error, _reason} ->
        {:noreply, put_flash(socket, :error, "ERROR DIRECTLY CALL 911 RAKA GANTENG")}
    end
  end

  def handle_event("search_domain_list", %{"domain_search" => %{"q" => q}}, socket) do
    {:noreply, assign(socket, :list_domain_query, String.trim(q || ""))}
  end

  def handle_event("create_shortlink", %{"shortlink" => params}, socket) do
    allowed_domains = shortlink_available_domain_names(socket.assigns.domains, socket.assigns.remote_domains)

    case Shortlink.create_short_link(params, socket.assigns.current_admin.id, allowed_domains) do
      {:ok, _short_link} ->
        {:noreply,
         socket
         |> put_flash(:info, "Shortlink berhasil dibuat.")
         |> assign_shortlink_list()
         |> assign_shortlink_stats()
         |> assign(:shortlink_form, to_form(Shortlink.new_short_link_form_defaults(allowed_domains), as: :shortlink))}

      {:error, _reason} ->
        {:noreply, put_flash(socket, :error, "ERROR DIRECTLY CALL 911 RAKA GANTENG")}
    end
  end

  def handle_event("search_shortlink_list", %{"shortlink_search" => %{"q" => q}}, socket) do
    query = String.trim(q || "")
    {:noreply, socket |> assign(:shortlink_query, query) |> assign_shortlink_list()}
  end

  def handle_event("set_shortlink_redirect_type", %{"id" => id, "type" => type}, socket) do
    with {shortlink_id, _} <- Integer.parse(to_string(id)),
         {redirect_type, _} <- Integer.parse(to_string(type)),
         {:ok, _shortlink} <- Shortlink.update_redirect_type(shortlink_id, redirect_type) do
      {:noreply,
       socket
       |> put_flash(:info, "Redirect type diperbarui.")
       |> assign_shortlink_list()
       |> assign_shortlink_stats()}
    else
      _ ->
        {:noreply, put_flash(socket, :error, "ERROR DIRECTLY CALL 911 RAKA GANTENG")}
    end
  end

  def handle_event("search_shortlink_rotator", %{"shortlink_rotator_search" => %{"q" => q}}, socket) do
    query = String.trim(q || "")
    {:noreply, socket |> assign(:shortlink_rotator_query, query) |> assign_shortlink_rotator_data()}
  end

  def handle_event("edit_shortlink_rotator", %{"id" => id}, socket) do
    with {short_link_id, _} <- Integer.parse(to_string(id)),
         link when is_map(link) <- Enum.find(socket.assigns.shortlink_rotator_links, &(&1.id == short_link_id)) do
      {:noreply,
       socket
       |> assign(:rotator_form, to_form(rotator_form_from_link(link), as: :rotator))
       |> assign(:rotator_modal_open, true)
       |> assign(:rotator_modal_link, link)}
    else
      _ ->
        {:noreply, put_flash(socket, :error, "ERROR DIRECTLY CALL 911 RAKA GANTENG")}
    end
  end

  def handle_event("close_rotator_modal", _params, socket) do
    {:noreply, socket |> assign(:rotator_modal_open, false) |> assign(:rotator_modal_link, nil)}
  end

  def handle_event("save_shortlink_rotator", %{"rotator" => params}, socket) do
    case Shortlink.save_rotator_config(params) do
      {:ok, :saved} ->
        {:noreply,
         socket
         |> put_flash(:info, "Rotator shortlink berhasil disimpan.")
         |> assign_shortlink_rotator_data()
         |> assign(:rotator_form, to_form(Shortlink.new_rotator_form_defaults(), as: :rotator))}

      {:error, _reason} ->
        {:noreply, put_flash(socket, :error, "ERROR DIRECTLY CALL 911 RAKA GANTENG")}
    end
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
      {:error, _reason} ->
        {:noreply, put_flash(socket, :error, "ERROR DIRECTLY CALL 911 RAKA GANTENG")}

      _ ->
        {:noreply, put_flash(socket, :error, "ERROR DIRECTLY CALL 911 RAKA GANTENG")}
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
        {:noreply, put_flash(socket, :error, "ERROR DIRECTLY CALL 911 RAKA GANTENG")}
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

      {:error, _reason} ->
        {:noreply, put_flash(socket, :error, "ERROR DIRECTLY CALL 911 RAKA GANTENG")}
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
         |> put_flash(:error, "ERROR DIRECTLY CALL 911 RAKA GANTENG")
         |> assign(:sflink_profile_form, to_form(changeset, as: :sflink_profile))}

      {:error, :token_limit} ->
        {:noreply,
         socket
         |> put_flash(:error, "ERROR DIRECTLY CALL 911 RAKA GANTENG")}

      {:error, _reason} ->
        {:noreply, put_flash(socket, :error, "ERROR DIRECTLY CALL 911 RAKA GANTENG")}
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
      {:error, _reason} ->
        {:noreply, put_flash(socket, :error, "ERROR DIRECTLY CALL 911 RAKA GANTENG")}

      _ ->
        {:noreply, put_flash(socket, :error, "ERROR DIRECTLY CALL 911 RAKA GANTENG")}
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
      {:error, _reason} ->
        {:noreply, put_flash(socket, :error, "ERROR DIRECTLY CALL 911 RAKA GANTENG")}

      _ ->
        {:noreply, put_flash(socket, :error, "ERROR DIRECTLY CALL 911 RAKA GANTENG")}
    end
  end

  def handle_event("run_checker_now", _params, socket) do
    case ElixirNawalaDK168.Workers.CheckerCycleWorker.enqueue() do
      {:ok, _job} ->
        {:noreply, put_flash(socket, :info, "Checker cycle berhasil di-queue.")}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "ERROR DIRECTLY CALL 911 RAKA GANTENG")}
    end
  end

  def handle_event("test_group", _params, socket) do
    msg = socket.assigns.test_message
    reply = if Notifier.send_test_message(:group, msg) == :ok, do: {:info, "Test message ke group terkirim."}, else: {:error, "ERROR DIRECTLY CALL 911 RAKA GANTENG"}
    {:noreply, put_flash(socket, elem(reply, 0), elem(reply, 1))}
  end

  def handle_event("test_private", _params, socket) do
    msg = socket.assigns.test_message
    reply = if Notifier.send_test_message(:private, msg) == :ok, do: {:info, "Test message ke private chat terkirim."}, else: {:error, "ERROR DIRECTLY CALL 911 RAKA GANTENG"}
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

  def handle_event("toggle_shortlink_menu", _params, socket) do
    {:noreply, assign(socket, :shortlink_menu_open, !socket.assigns.shortlink_menu_open)}
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

          <div class={["menu-expand", @shortlink_menu_open && "open"]} data-pop-title="Shortlink">
            <button type="button" class={menu_class(@current_page in [:shortlink_create, :shortlink_list, :shortlink_stats, :shortlink_rotator])} phx-click="toggle_shortlink_menu">
              <span class="menu-arrow"></span>
              <span class="menu-icon">
                <.nav_icon name="shortlink" />
              </span>
              <span class="menu-label">Shortlink</span>
            </button>
            <div class="submenu-pop">
              <p class="submenu-pop-title">Shortlink</p>
              <.link class={submenu_class(@current_page == :shortlink_create)} href="/admin/shortlink/create">Create Shortlink</.link>
              <.link class={submenu_class(@current_page == :shortlink_list)} href="/admin/shortlink/list">List Shortlink</.link>
              <.link class={submenu_class(@current_page == :shortlink_stats)} href="/admin/shortlink/stats">Stats Shortlink</.link>
              <.link class={submenu_class(@current_page == :shortlink_rotator)} href="/admin/shortlink/rotator">Rotator</.link>
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

          <%= if @current_page == :shortlink_create do %>
            <section id="shortlink-create" class="card-dark shortlink-shell">
              <div class="shortlink-head-row">
                <div class="shortlink-head">
                  <h2>Create Shortlink</h2>
                  <p>Kelola tautan singkat berbasis slug dengan struktur yang konsisten dan mudah dipantau.</p>
                </div>
                <div class="shortlink-head-meta">
                  <span class="shortlink-meta-pill">Slug Based</span>
                  <span class="shortlink-meta-pill">Click Tracking</span>
                </div>
              </div>

              <div class="shortlink-pattern">
                <span class="pattern-label">Format URL</span>
                <code>{shortlink_pattern_url()}</code>
              </div>

              <div class="shortlink-create-grid">
                <article class="card-dark shortlink-form-card">
                  <h3>Generate Link</h3>
                  <p class="shortlink-card-subtitle">Isi destination URL, tentukan slug, lalu pilih tipe redirect.</p>
                  <.form for={@shortlink_form} phx-submit="create_shortlink" class="shortlink-form-grid">
                    <div class="shortlink-field">
                      <label>Destination URL</label>
                      <div class="shortlink-select-wrap">
                        <span class="shortlink-select-prefix">https://</span>
                        <select class="shortlink-domain-select" name="shortlink[destination_url]" required>
                          <option :if={shortlink_domain_options(@domains, @remote_domains) == []} value="">Tidak ada domain tersedia</option>
                          <option :if={shortlink_domain_options(@domains, @remote_domains) != []} value="" disabled={true}>Pilih domain tujuan</option>
                          <optgroup :if={active_shortlink_domains(shortlink_domain_options(@domains, @remote_domains)) != []} label="Active Domains">
                            <option
                              :for={domain <- active_shortlink_domains(shortlink_domain_options(@domains, @remote_domains))}
                              value={"https://#{domain}"}
                              selected={to_string(@shortlink_form[:destination_url].value) == "https://#{domain}"}
                            >
                              {shortlink_domain_option_label(domain)}
                            </option>
                          </optgroup>
                          <optgroup :if={inactive_shortlink_domains(shortlink_domain_options(@domains, @remote_domains)) != []} label="Inactive Domains">
                            <option
                              :for={domain <- inactive_shortlink_domains(shortlink_domain_options(@domains, @remote_domains))}
                              value={"https://#{domain}"}
                              selected={to_string(@shortlink_form[:destination_url].value) == "https://#{domain}"}
                            >
                              {shortlink_domain_option_label(domain)}
                            </option>
                          </optgroup>
                        </select>
                      </div>
                      <p class="shortlink-help">Hanya domain dari List Domain yang bisa dipilih.</p>
                    </div>

                    <div class="shortlink-field">
                      <label>Custom Slug (opsional)</label>
                      <input
                        type="text"
                        name="shortlink[slug]"
                        value={@shortlink_form[:slug].value}
                        placeholder="promo-seo-2026"
                        autocomplete="off"
                      />
                      <p class="shortlink-help">Kosongkan untuk generate slug random otomatis.</p>
                    </div>

                    <div class="shortlink-field">
                      <label>Redirect Type</label>
                      <select name="shortlink[redirect_type]">
                        <option value="302" selected={to_string(@shortlink_form[:redirect_type].value) == "302"}>302 (Temporary)</option>
                        <option value="301" selected={to_string(@shortlink_form[:redirect_type].value) == "301"}>301 (Permanent)</option>
                      </select>
                    </div>

                    <div class="actions">
                      <button type="submit" class="shortlink-submit-btn" disabled={shortlink_domain_options(@domains, @remote_domains) == []}>Generate Shortlink</button>
                    </div>
                  </.form>
                </article>

                <article class="card-dark shortlink-guide-card">
                  <h3>Panduan Cepat</h3>
                  <p class="shortlink-card-subtitle">Praktik yang disarankan supaya shortlink mudah dikelola tim.</p>
                  <div class="shortlink-guide-list">
                    <div class="shortlink-guide-item">
                      <span class="guide-step">1</span>
                      <div>
                        <strong>Gunakan URL final</strong>
                        <p>Hindari URL dengan banyak redirect berantai agar klik lebih cepat.</p>
                      </div>
                    </div>
                    <div class="shortlink-guide-item">
                      <span class="guide-step">2</span>
                      <div>
                        <strong>Pakai slug deskriptif</strong>
                        <p>Gunakan pola yang mudah diingat untuk campaign jangka panjang.</p>
                      </div>
                    </div>
                    <div class="shortlink-guide-item">
                      <span class="guide-step">3</span>
                      <div>
                        <strong>Pilih redirect sesuai tujuan</strong>
                        <p>302 untuk campaign aktif, 301 untuk URL permanen atau evergreen.</p>
                      </div>
                    </div>
                  </div>

                  <div class="shortlink-preview-box">
                    <p class="preview-title">Preview URL</p>
                    <code>{shortlink_pattern_url()}</code>
                  </div>
                </article>
              </div>
            </section>
          <% end %>

          <%= if @current_page == :shortlink_list do %>
            <section id="shortlink-list" class="card-dark shortlink-shell">
              <div class="shortlink-list-head">
                <div>
                  <h2 class="list-domain-title">List Shortlink</h2>
                  <p class="shortlink-list-subtitle">Kelola seluruh shortlink, redirect type, dan performa klik dari satu tabel.</p>
                </div>
                <div class="shortlink-list-metrics">
                  <span class="shortlink-metric-chip">Total: {length(@shortlink_list)}</span>
                  <span class="shortlink-metric-chip">Clicks: {Enum.sum(Enum.map(@shortlink_list, &(&1.click_count || 0)))}</span>
                </div>
              </div>

              <div class="list-domain-head shortlink-list-toolbar">
                <.form for={to_form(%{"q" => @shortlink_query}, as: :shortlink_search)} phx-change="search_shortlink_list" class="list-domain-search-form shortlink-list-search-form">
                  <input
                    type="text"
                    name="shortlink_search[q]"
                    value={@shortlink_query}
                    placeholder="Cari slug atau destination..."
                    class="list-domain-search"
                    phx-debounce="250"
                    autocomplete="off"
                  />
                </.form>
              </div>

              <div class="table-wrap">
                <table class="domain-list-table shortlink-table shortlink-list-table">
                  <thead>
                    <tr>
                      <th>Slug</th>
                      <th>Short URL</th>
                      <th>Destination</th>
                      <th>Redirect</th>
                      <th>Clicks</th>
                      <th class="action-col">Action</th>
                    </tr>
                  </thead>
                  <tbody>
                    <tr :for={link <- @shortlink_list}>
                      <td class="shortlink-slug-cell"><code class="shortlink-slug-code">{link.slug}</code></td>
                      <td class="shortlink-url-cell">
                        <span class="shortlink-url-text">{Shortlink.short_url_for_slug(link.slug)}</span>
                      </td>
                      <td class="shortlink-destination-cell">
                        <span class="shortlink-destination-text">{link.destination_url}</span>
                      </td>
                      <td><span class={["badge", shortlink_redirect_badge_class(link.redirect_type)]}>{link.redirect_type}</span></td>
                      <td><span class="badge shortlink-click-badge">{link.click_count} clicks</span></td>
                      <td class="action-col">
                        <button
                          class="shortlink-action-btn"
                          phx-click="set_shortlink_redirect_type"
                          phx-value-id={link.id}
                          phx-value-type={if link.redirect_type == 301, do: 302, else: 301}
                        >
                          Switch to {if link.redirect_type == 301, do: "302", else: "301"}
                        </button>
                      </td>
                    </tr>
                    <tr :if={@shortlink_list == []}>
                      <td colspan="6" class="shortlink-empty-state">Belum ada shortlink.</td>
                    </tr>
                  </tbody>
                </table>
              </div>
            </section>
          <% end %>

          <%= if @current_page == :shortlink_stats do %>
            <section id="shortlink-stats" class="card-dark shortlink-shell">
              <div class="shortlink-stats-head">
                <div>
                  <h2 class="shortlink-stats-title">Shortlink Stats</h2>
                  <p class="shortlink-stats-subtitle">Pantau performa shortlink, klik terbaru, dan link paling aktif secara realtime.</p>
                </div>
                <span class="shortlink-stats-chip">Updated Live</span>
              </div>

              <div class="shortlink-kpi-grid">
                <article class="shortlink-kpi-card">
                  <p class="kpi-label">Total Link</p>
                  <p class="kpi-value">{@shortlink_stats[:total_links] || 0}</p>
                </article>
                <article class="shortlink-kpi-card">
                  <p class="kpi-label">Link Aktif</p>
                  <p class="kpi-value">{@shortlink_stats[:active_links] || 0}</p>
                </article>
                <article class="shortlink-kpi-card">
                  <p class="kpi-label">Total Clicks</p>
                  <p class="kpi-value">{@shortlink_stats[:total_clicks] || 0}</p>
                </article>
                <article class="shortlink-kpi-card">
                  <p class="kpi-label">Clicks Hari Ini</p>
                  <p class="kpi-value">{@shortlink_stats[:today_clicks] || 0}</p>
                </article>
              </div>

              <div class="shortlink-stats-grid">
                <article class="card-dark shortlink-top-card">
                  <h3>Top Links</h3>
                  <table class="shortlink-top-table">
                    <thead>
                      <tr>
                        <th>#</th>
                        <th>Slug</th>
                        <th>Clicks</th>
                      </tr>
                    </thead>
                    <tbody>
                      <tr :for={{link, idx} <- Enum.with_index(@shortlink_stats[:top_links] || [], 1)}>
                        <td><span class="shortlink-rank-chip">{"##{idx}"}</span></td>
                        <td><code>{link.slug}</code></td>
                        <td><span class="badge shortlink-click-badge">{link.click_count}</span></td>
                      </tr>
                      <tr :if={(@shortlink_stats[:top_links] || []) == []}>
                        <td colspan="3" class="shortlink-empty-state">Belum ada data.</td>
                      </tr>
                    </tbody>
                  </table>
                </article>

                <article class="card-dark shortlink-log-card">
                  <h3>Recent Click Log</h3>
                  <div class="table-wrap shortlink-log-wrap">
                    <table class="domain-list-table shortlink-log-table">
                      <thead>
                        <tr>
                          <th>Waktu</th>
                          <th>Slug</th>
                          <th>IP</th>
                          <th>Referrer</th>
                        </tr>
                      </thead>
                      <tbody>
                        <tr :for={click <- @shortlink_recent_clicks}>
                          <td>{format_shortlink_time(click.clicked_at)}</td>
                          <td><code>{click.short_link.slug}</code></td>
                          <td><span class="shortlink-ip-chip">{click.ip_address || "-"}</span></td>
                          <td><span class="shortlink-referrer-text">{click.referrer || "-"}</span></td>
                        </tr>
                        <tr :if={@shortlink_recent_clicks == []}>
                          <td colspan="4" class="shortlink-empty-state">Belum ada click log.</td>
                        </tr>
                      </tbody>
                    </table>
                  </div>
                </article>
              </div>
            </section>
          <% end %>

          <%= if @current_page == :shortlink_rotator do %>
            <section id="shortlink-rotator" class="card-dark shortlink-shell">
              <div class="shortlink-list-head rotator-head">
                <div class="rotator-head-main">
                  <h2 class="list-domain-title">Rotator Shortlink</h2>
                  <p class="shortlink-list-subtitle">Kelola domain fallback per shortlink. Saat domain utama terdeteksi blocked, sistem akan failover otomatis ke domain cadangan sesuai prioritas.</p>
                </div>
                <div class="rotator-metrics">
                  <span class="rotator-metric-chip">
                    <strong>{length(@shortlink_rotator_list)}</strong>
                    <small>Links</small>
                  </span>
                  <span class="rotator-metric-chip">
                    <strong>{length(@domains)}</strong>
                    <small>Domains</small>
                  </span>
                  <span class="rotator-metric-chip">
                    <strong>
                      {Enum.count(@shortlink_rotator_list, fn link ->
                        case Map.get(link, :rotator) do
                          %{enabled: true} -> true
                          _ -> false
                        end
                      end)}
                    </strong>
                    <small>Active</small>
                  </span>
                </div>
              </div>

              <div class="admin-grid profile-grid rotator-grid">
                <article class="card-dark shortlink-form-card rotator-config-card">
                  <div class="rotator-config-head">
                    <div>
                      <h3>Pengaturan Rotator</h3>
                      <p class="shortlink-card-subtitle">Pilih shortlink, atur domain fallback, lalu aktifkan failover otomatis.</p>
                      <div class="rotator-inline-stats">
                        <span class="rotator-inline-chip">Trusted Fallback: {length(@rotator_fallback_domains)}</span>
                        <span class="rotator-inline-chip">Shortlink Tersedia: {length(@shortlink_rotator_links)}</span>
                      </div>
                    </div>
                    <span class="rotator-config-pill">Failover Rules</span>
                  </div>

                  <div class="rotator-form-panel">
                    <.form for={@rotator_form} phx-submit="save_shortlink_rotator" class="shortlink-form-grid rotator-form-grid">
                      <div class="shortlink-field rotator-field-block">
                        <label>
                          Shortlink
                          <small class="rotator-label-meta">Slug sumber</small>
                        </label>
                        <select class="rotator-select" name="rotator[short_link_id]" required>
                          <option value="">Pilih Slug Shortlink</option>
                          <option
                            :for={link <- @shortlink_rotator_links}
                            value={link.id}
                            selected={to_string(@rotator_form[:short_link_id].value) == to_string(link.id)}
                          >
                            {"#{link.slug} -> #{primary_domain_from_url(link.destination_url)}"}
                          </option>
                        </select>
                      </div>

                      <div class="shortlink-field rotator-field-block">
                        <label>
                          Fallback Domain
                          <small class="rotator-label-meta">Urutan prioritas</small>
                        </label>
                        <select class="rotator-select rotator-select-multi" name="rotator[fallback_domain_ids][]" multiple size="1">
                        <option :if={@rotator_fallback_domains == []} value="" disabled={true}>Tidak ada fallback domain trusted tersedia</option>
                        <option
                          :for={domain <- @rotator_fallback_domains}
                          value={domain.id}
                          selected={to_string(domain.id) in normalize_selected_ids(@rotator_form[:fallback_domain_ids].value)}
                        >
                          {domain.name}
                          </option>
                        </select>
                        <p class="shortlink-help">Tekan Ctrl/Cmd untuk memilih lebih dari satu domain.</p>
                      </div>

                      <label class="checkbox-label rotator-checkbox">
                        <input type="checkbox" name="rotator[enabled]" value="true" checked={to_string(@rotator_form[:enabled].value) == "true"} />
                        Aktifkan rotator untuk shortlink ini
                      </label>

                      <div class="actions rotator-actions">
                        <button type="submit" class="rotator-submit-btn">Simpan Rotator</button>
                      </div>
                    </.form>
                  </div>

                </article>

                <article class="card-dark shortlink-guide-card">
                  <div class="rotator-list-headline">
                    <h3>Daftar Rotator Aktif</h3>
                    <span class="rotator-hint-chip">Auto Failover</span>
                  </div>
                  <p class="shortlink-card-subtitle">Pantau konfigurasi slug, domain utama, fallback, dan status rotator pada satu tabel.</p>
                  <.form for={to_form(%{"q" => @shortlink_rotator_query}, as: :shortlink_rotator_search)} phx-change="search_shortlink_rotator" class="list-domain-search-form shortlink-list-search-form">
                    <input
                      type="text"
                      name="shortlink_rotator_search[q]"
                      value={@shortlink_rotator_query}
                      placeholder="Cari slug atau domain..."
                      class="list-domain-search"
                      phx-debounce="250"
                      autocomplete="off"
                    />
                  </.form>

                  <div class="table-wrap rotator-table-wrap">
                    <table class="domain-list-table shortlink-table rotator-table">
                      <thead>
                        <tr>
                          <th>Slug</th>
                          <th>Primary Domain</th>
                          <th>Status</th>
                          <th class="action-col">Action</th>
                        </tr>
                      </thead>
                      <tbody>
                        <tr :for={link <- @shortlink_rotator_list}>
                          <td><code class="rotator-slug-code">{link.slug}</code></td>
                          <td><span class="rotator-primary-domain">{primary_domain_from_url(link.destination_url)}</span></td>
                          <td>
                            <span class={["badge", "rotator-status-badge", rotator_status_badge(link)]}>{rotator_status_label(link)}</span>
                          </td>
                          <td class="action-col rotator-action-cell">
                            <button class="rotator-edit-btn" type="button" phx-click="edit_shortlink_rotator" phx-value-id={link.id}>Edit</button>
                          </td>
                        </tr>
                        <tr :if={@shortlink_rotator_list == []}>
                          <td colspan="4" class="shortlink-empty-state">Belum ada shortlink.</td>
                        </tr>
                      </tbody>
                    </table>
                  </div>
                  <p class="rotator-list-meta">Total konfigurasi: {length(@shortlink_rotator_list)}</p>
                </article>
              </div>

              <div :if={@rotator_modal_open and is_map(@rotator_modal_link)} class="rotator-modal-layer">
                <button type="button" class="rotator-modal-backdrop" phx-click="close_rotator_modal" aria-label="Tutup detail rotator"></button>
                <section class="rotator-modal-card" role="dialog" aria-modal="true" aria-label="Detail rotator">
                  <div class="rotator-modal-head">
                    <h3>Detail Rotator</h3>
                    <button type="button" class="rotator-modal-close" phx-click="close_rotator_modal">Tutup</button>
                  </div>

                  <div class="rotator-modal-grid">
                    <div class="rotator-modal-item">
                      <span class="rotator-modal-label">Slug</span>
                      <code class="rotator-modal-value">{@rotator_modal_link.slug}</code>
                    </div>
                    <div class="rotator-modal-item">
                      <span class="rotator-modal-label">Primary Domain</span>
                      <span class="rotator-modal-value">{primary_domain_from_url(@rotator_modal_link.destination_url)}</span>
                    </div>
                    <div class="rotator-modal-item">
                      <span class="rotator-modal-label">Status Rotator</span>
                      <span class={["badge", "rotator-status-badge", rotator_status_badge(@rotator_modal_link)]}>{rotator_status_label(@rotator_modal_link)}</span>
                    </div>
                  </div>

                  <div class="rotator-modal-fallback">
                    <p class="rotator-modal-label">Fallback Domain</p>
                    <ul>
                      <li :for={domain <- rotator_fallback_list(@rotator_modal_link)}>{domain}</li>
                      <li :if={rotator_fallback_list(@rotator_modal_link) == []}>Belum ada fallback domain.</li>
                    </ul>
                  </div>
                </section>
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

      {:error, _reason} ->
        socket
        |> assign(:remote_domains, [])
        |> maybe_flash_error(show_error, "ERROR DIRECTLY CALL 911 RAKA GANTENG")

      _ ->
        socket
        |> assign(:remote_domains, [])
        |> maybe_flash_error(show_error, "ERROR DIRECTLY CALL 911 RAKA GANTENG")
    end
  end

  defp page_from_action(:add_domain), do: :add_domain
  defp page_from_action(:list_domain), do: :list_domain
  defp page_from_action(:status_domain), do: :status_domain
  defp page_from_action(:telegram), do: :telegram
  defp page_from_action(:profile), do: :profile
  defp page_from_action(:shortlink_create), do: :shortlink_create
  defp page_from_action(:shortlink_list), do: :shortlink_list
  defp page_from_action(:shortlink_stats), do: :shortlink_stats
  defp page_from_action(:shortlink_rotator), do: :shortlink_rotator
  defp page_from_action(_), do: :home

  defp page_title(:add_domain), do: "Add Domain"
  defp page_title(:list_domain), do: "List Domain"
  defp page_title(:status_domain), do: "Domain Status"
  defp page_title(:telegram), do: "Telegram"
  defp page_title(:profile), do: "Profile"
  defp page_title(:shortlink_create), do: "Create Shortlink"
  defp page_title(:shortlink_list), do: "List Shortlink"
  defp page_title(:shortlink_stats), do: "Shortlink Stats"
  defp page_title(:shortlink_rotator), do: "Rotator Shortlink"
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
      <% "shortlink" -> %>
        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">
          <path d="M10 14a3 3 0 0 1 0-4l2-2a3 3 0 1 1 4.2 4.2l-1 1"/>
          <path d="M14 10a3 3 0 0 1 0 4l-2 2a3 3 0 1 1-4.2-4.2l1-1"/>
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

  defp format_reason({:http_error, _code, _message, _body}), do: "ERROR DIRECTLY CALL 911 RAKA GANTENG"
  defp format_reason({:sflink_error, _message, _body}), do: "ERROR DIRECTLY CALL 911 RAKA GANTENG"
  defp format_reason({:invalid_response, _body}), do: "ERROR DIRECTLY CALL 911 RAKA GANTENG"
  defp format_reason(_reason), do: "ERROR DIRECTLY CALL 911 RAKA GANTENG"

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
      socket.assigns.remote_domains
      |> Monitor.live_check_remote_domains()
      |> then(&Map.merge(socket.assigns.remote_statuses, &1))

    assign(socket, :remote_statuses, statuses)
  end

  defp parse_id_param(value) when is_integer(value), do: {:ok, value}

  defp parse_id_param(value) when is_binary(value) do
    case Integer.parse(String.trim(value)) do
      {int, _} -> {:ok, int}
      _ -> {:error, :invalid_id}
    end
  end

  defp parse_id_param(_), do: {:error, :invalid_id}

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

  defp assign_shortlink_list(socket) do
    query = socket.assigns.shortlink_query || ""
    assign(socket, :shortlink_list, Shortlink.list_short_links(query))
  end

  defp assign_shortlink_stats(socket) do
    socket
    |> assign(:shortlink_stats, Shortlink.get_stats())
    |> assign(:shortlink_recent_clicks, Shortlink.list_recent_clicks(50))
  end

  defp assign_shortlink_rotator_data(socket) do
    query = socket.assigns.shortlink_rotator_query || ""
    list = Shortlink.list_rotator_configs(query)
    trusted_fallback_domains =
      trusted_rotator_fallback_domains(
        socket.assigns.domains,
        socket.assigns.remote_domains,
        socket.assigns.remote_statuses
      )

    socket
    |> assign(:shortlink_rotator_list, list)
    |> assign(:shortlink_rotator_links, Shortlink.list_rotator_configs(""))
    |> assign(:rotator_fallback_domains, trusted_fallback_domains)
  end

  defp shortlink_pattern_url do
    base = ElixirNawalaDK168Web.Endpoint.url() |> String.trim_trailing("/")
    "#{base}/s/{slug}"
  end

  defp shortlink_domain_names(domains) when is_list(domains) do
    domains
    |> Enum.map(fn
      %{name: name} -> to_string(name || "")
      value when is_binary(value) -> value
      _ -> ""
    end)
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == ""))
    |> Enum.map(&String.downcase/1)
    |> Enum.uniq()
  end

  defp shortlink_domain_names(_), do: []

  defp active_shortlink_domains(domains) when is_list(domains) do
    domains
  end

  defp active_shortlink_domains(_), do: []

  defp inactive_shortlink_domains(domains) when is_list(domains) do
    []
  end

  defp inactive_shortlink_domains(_), do: []

  defp shortlink_domain_option_label(domain) when is_binary(domain), do: domain

  defp shortlink_domain_option_label(_), do: "-"

  defp shortlink_domain_options(local_domains, remote_domains) do
    shortlink_available_domain_names(local_domains, remote_domains)
  end

  defp shortlink_available_domain_names(local_domains, remote_domains) do
    local = shortlink_domain_names(local_domains)

    remote =
      remote_domains
      |> List.wrap()
      |> Enum.map(fn
        %{domain: domain} -> to_string(domain || "")
        value when is_binary(value) -> value
        _ -> ""
      end)
      |> shortlink_domain_names()

    (local ++ remote)
    |> Enum.uniq()
    |> Enum.sort()
  end

  defp shortlink_redirect_badge_class(301), do: "shortlink-redirect-permanent"
  defp shortlink_redirect_badge_class("301"), do: "shortlink-redirect-permanent"
  defp shortlink_redirect_badge_class(_), do: "shortlink-redirect-temporary"

  defp rotator_form_from_link(link) when is_map(link) do
    fallback_ids =
      case Map.get(link, :rotator) do
        nil ->
          []

        rotator ->
          rotator.rotator_domains
          |> Enum.sort_by(& &1.priority)
          |> Enum.map(&to_string(&1.domain_id))
      end

    %{
      "short_link_id" => to_string(link.id),
      "enabled" => if(Map.get(link, :rotator) && link.rotator.enabled, do: "true", else: "false"),
      "fallback_domain_ids" => fallback_ids
    }
  end

  defp rotator_form_from_link(_), do: Shortlink.new_rotator_form_defaults()

  defp normalize_selected_ids(values) when is_list(values) do
    values
    |> Enum.map(&to_string/1)
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == ""))
  end

  defp normalize_selected_ids(value) when is_binary(value), do: [String.trim(value)]
  defp normalize_selected_ids(_), do: []

  defp primary_domain_from_url(url) when is_binary(url) do
    case URI.parse(url) do
      %URI{host: host} when is_binary(host) and host != "" -> host
      _ -> "-"
    end
  end

  defp primary_domain_from_url(_), do: "-"

  defp rotator_fallback_domains(link) when is_map(link) do
    case Map.get(link, :rotator) do
      nil ->
        "-"

      rotator ->
        rotator.rotator_domains
        |> Enum.sort_by(& &1.priority)
        |> Enum.map(fn row -> row.domain && row.domain.name end)
        |> Enum.reject(&is_nil/1)
        |> case do
          [] -> "-"
          names -> Enum.join(names, ", ")
        end
    end
  end

  defp rotator_fallback_domains(_), do: "-"

  defp rotator_fallback_list(link) when is_map(link) do
    case Map.get(link, :rotator) do
      nil ->
        []

      rotator ->
        rotator.rotator_domains
        |> Enum.sort_by(& &1.priority)
        |> Enum.map(fn row -> row.domain && row.domain.name end)
        |> Enum.reject(&is_nil/1)
    end
  end

  defp rotator_fallback_list(_), do: []

  defp rotator_status_label(link) when is_map(link) do
    case Map.get(link, :rotator) do
      %{enabled: true} -> "Enabled"
      %{enabled: false} -> "Disabled"
      _ -> "Not Set"
    end
  end

  defp rotator_status_label(_), do: "Not Set"

  defp rotator_status_badge(link) when is_map(link) do
    case Map.get(link, :rotator) do
      %{enabled: true} -> "badge-green"
      %{enabled: false} -> "badge-amber"
      _ -> "badge-gray"
    end
  end

  defp rotator_status_badge(_), do: "badge-gray"

  defp trusted_rotator_fallback_domains(domains, remote_domains, remote_statuses) do
    trusted_remote_names =
      remote_domains
      |> List.wrap()
      |> Enum.filter(&(check_status_text(&1, remote_statuses) == "TRUSTED"))
      |> Enum.map(fn rd -> rd.domain end)
      |> Enum.map(&to_string/1)
      |> Enum.map(&String.trim/1)
      |> Enum.reject(&(&1 == ""))
      |> Enum.map(&String.downcase/1)
      |> MapSet.new()

    domains
    |> List.wrap()
    |> Enum.filter(fn domain ->
      name =
        domain
        |> Map.get(:name, "")
        |> to_string()
        |> String.trim()
        |> String.downcase()

      Map.get(domain, :active) == true and
        (Map.get(domain, :last_status) in ["up"] or MapSet.member?(trusted_remote_names, name))
    end)
    |> Enum.sort_by(fn domain -> String.downcase(to_string(Map.get(domain, :name, ""))) end)
  end

  defp format_shortlink_time(nil), do: "-"

  defp format_shortlink_time(%DateTime{} = dt) do
    Calendar.strftime(dt, "%d-%m-%Y %H:%M:%S UTC")
  end

  defp format_shortlink_time(%NaiveDateTime{} = ndt) do
    ndt
    |> DateTime.from_naive!("Etc/UTC")
    |> format_shortlink_time()
  end

  defp format_shortlink_time(_), do: "-"

end

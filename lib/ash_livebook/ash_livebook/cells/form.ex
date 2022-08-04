defmodule AshLivebook.Cells.Form do
  use Kino.JS
  use Kino.JS.Live
  use Kino.SmartCell, name: "Resource Form"

  @impl true
  def init(attrs, ctx) do
    resource =
      case attrs["resource"] || nil do
        "" ->
          nil

        resource ->
          resource
      end

    action = attrs["action"] || nil
    resources = resources()

    {:ok,
     assign(ctx,
       resource: resource,
       action: action,
       resources: resources,
       actions: actions(resource)
     )}
  end

  defp resources do
    loaded_applications()
    |> Enum.flat_map(fn app ->
      {:ok, modules} = :application.get_key(app, :modules)
      modules
    end)
    |> Enum.filter(fn module ->
      try do
        Ash.Dsl.is?(module, Ash.Resource)
      rescue
        _ ->
          false
      end
    end)
    |> Enum.map(&inspect/1)
  end

  defp loaded_applications do
    # If we invoke :application.loaded_applications/0,
    # it can error if we don't call safe_fixtable before.
    # Since in both cases we are reaching over the
    # application controller internals, we choose to match
    # for performance.
    for [app] <- :ets.match(:ac_tab, {{:loaded, :"$1"}, :_}), do: app
  end

  @impl true
  def handle_connect(ctx) do
    {:ok,
     %{
       resource: ctx.assigns.resource,
       action: ctx.assigns.action,
       resources: ctx.assigns.resources,
       actions: ctx.assigns.actions
     }, ctx}
  end

  @impl true
  def handle_event("update_resource", %{"resource" => resource}, ctx) do
    resource =
      if resource == "" do
        nil
      else
        resource
      end

    actions = actions(resource)

    broadcast_event(ctx, "update", %{
      "resource" => resource,
      "actions" => actions,
      "action" => ctx.assigns.action,
      "resources" => ctx.assigns.resources
    })

    {:noreply, assign(ctx, resource: resource, actions: actions)}
  end

  @impl true
  def handle_event("update_action", %{"action" => action}, ctx) do
    broadcast_event(ctx, "update", %{
      "resource" => ctx.assigns.resource,
      "actions" => ctx.assigns.actions,
      "action" => action,
      "resources" => ctx.assigns.resources
    })

    {:noreply, assign(ctx, action: action)}
  end

  defp actions(resource) do
    if resource do
      resource = String.to_existing_atom("Elixir.#{resource}")
      resource |> Ash.Resource.Info.actions() |> Enum.map(&to_string(&1.name))
    else
      []
    end
  end

  @impl true
  def to_attrs(ctx) do
    %{
      "resource" => ctx.assigns.resource,
      "action" => ctx.assigns.action,
      "resources" => ctx.assigns.resources,
      "actions" => ctx.assigns.actions
    }
  end

  @impl true
  def to_source(%{"resource" => resource, "action" => action}) do
    if resource && action do
      resource = String.to_existing_atom("Elixir.#{resource}")
      "Ash.Resource.Info.action(#{inspect(resource)}, :#{action})"
    else
      ""
    end
  end

  asset "main.js" do
    """
    export function init(ctx, payload) {
      ctx.importCSS("main.css");

      function render(resource, action, resources, actions) {
        if(resource && action) {
          ctx.root.innerHTML = 'form for ' + resource + ': ' + action;
        } else {
          ctx.root.innerHTML = ``;

          const input = document.createElement('select');

          var opt = document.createElement('option');
          opt.value = "";
          opt.innerHTML = "";
          if(!action) {
            opt.selected = true;
          }

          input.appendChild(opt);

          input.addEventListener("change", (event) => {
            ctx.pushEvent("update_resource", { resource: event.target.value });
          });

          resources.forEach((resourceOption) => {
            var opt = document.createElement('option');
            opt.value = resourceOption;
            opt.innerHTML = resourceOption;
            if(resourceOption === resource) {
              opt.selected = true;
            }
            input.appendChild(opt);
          })

          ctx.root.appendChild(input);

          let actionSelect;

          if (resource) {
            actionSelect = document.createElement('select');
            actionSelect.id = "action"

            var opt = document.createElement('option');
            opt.value = "";
            opt.innerHTML = "";
            if(!action) {
              opt.selected = true;
            }

            actionSelect.appendChild(opt);

            actions.forEach((actionOption) => {
              var opt = document.createElement('option');
              opt.value = actionOption;
              opt.innerHTML = actionOption;
              if(action === actionOption) {
                opt.selected = true;
              }
              actionSelect.appendChild(opt);
            })

            ctx.root.appendChild(actionSelect);
            actionSelect.addEventListener("change", (event) => {
              ctx.pushEvent("update_action", { action: event.target.value });
            });
          }
        }
      }

      render(payload.resource, payload.action, payload.resources, payload.actions)

      ctx.handleEvent("update", ({ resource, action, resources, actions }) => {
        render(resource, action, resources, actions)
      });

      ctx.handleSync(() => {
        // Synchronously invokes change listeners
        document.activeElement &&
          document.activeElement.dispatchEvent(new Event("change"));
      });
    }
    """
  end

  asset "main.css" do
    """
    #foo {

    }
    """
  end
end

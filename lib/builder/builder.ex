defmodule Relexe.Builder do
  alias Burrito.Builder.Context
  alias Burrito.Builder.Log
  alias Burrito.Builder.Target

  alias Relexe.Steps.Build

  @moduledoc """
  Package builder.

  `relexe` uses a modified [Burrito](https://github.com/burrito-elixir/burrito) build pipline.  We substitute our own `build` phase.  Burrutio builds in "phases". Each phase contains any number of "steps" which are executed one after another.

  There are 3 phases:

  `:fetch` - This phase is responsible for downloading or copying in any replacement ERTS builds for cross-build targets.
  `:patch` - The patch phase injects custom scripts into the build directory, this phase is also where any custom files should be copied into the build directory before being archived.
  `:build` - This is the final phase in the build flow, it produces the executable binary.  This is the part of the Burrito build pipeline that we override.

  You can add your own steps before and after phases execute. Your custom steps will also receive the build context struct, and can return a modified one to customize a build to your liking.

  An example of adding a step before the fetch phase, and after the build phase:

  ```
  # ... mix.exs file
  def releases do
    [
      my_app: [
        steps: [:assemble, &Relexe.pack/1],
        relexe: [
          # ... other configuration
          extra_steps: [
            fetch: [pre: [MyCustomStepModule, AnotherCustomStepModule]],
            build: [post: [CustomStepAgain, YetAnotherCustomStepModule]]
            # ...
          ]
        ]
      ]
    ]
  end
  # ...
  ```
  """

  @phases [
    fetch: [Burrito.Steps.Fetch.Init, Burrito.Steps.Fetch.ResolveERTS],
    patch: [
      Burrito.Steps.Patch.CopyERTS,
      Burrito.Steps.Patch.RecompileNIFs
    ],
    build: [Build.PackAndBuild, Build.CopyRelease]
  ]

  def build(%Mix.Release{} = release) do
    options = release.options[:relexe] || []
    debug? = Keyword.get(options, :debug, false)

    build_targets = options[:targets]

    # look for override target in system env
    # if it's a valid target, set it as the only target
    target_override_string = System.get_env("RELEXE_TARGET")

    build_targets =
      if target_override_string do
        Log.warning(
          :build,
          "Target is being overridden with RELEXE_TARGET #{target_override_string}"
        )

        old_targets = Target.get_old_targets()

        override_atom =
          try do
            String.to_existing_atom(target_override_string)
          rescue
            _ -> raise_invalid_target(target_override_string)
          end

        # If we have a named target defined that matches this atom use that
        # otherwise if it's a legacy build target, translate it (this will be removed soon!)
        # otherwise :error, not a valid target
        cond do
          Keyword.has_key?(build_targets, override_atom) ->
            Keyword.take(build_targets, [override_atom])

          override_atom in old_targets ->
            resolved_override = Target.maybe_translate_old_target(override_atom)
            Keyword.put([], override_atom, resolved_override)

          true ->
            raise_invalid_target(override_atom)
        end
      else
        build_targets
      end

    # Build every target
    Enum.each(build_targets, fn {name, t} ->
      target = Target.init_target(name, t)
      target = %Target{target | debug?: debug?}

      self_path =
        __ENV__.file
        |> Path.dirname()
        |> Path.split()
        |> List.delete_at(-1)
        |> List.delete_at(-1)
        |> Path.join()

      initial_context = %Context{
        target: target,
        mix_release: release,
        work_dir: "",
        self_dir: self_path,
        halted: false
      }

      Log.info(:build, "relexe is building target: #{target.alias}")

      Log.info(
        :build,
        "relexe will build for target:\n\tOS: #{target.os}\n\tCPU: #{target.cpu}\n\tQualifiers: #{inspect(target.qualifiers)}\n\tDebug: #{target.debug?}"
      )

      Enum.reduce(@phases, initial_context, &run_phase/2)
    end)

    # All done!
    release
  end

  defp run_phase({phase_name, mod_list}, %Context{} = context) do
    Log.info(:phase, "PHASE: #{inspect(phase_name)}")

    # Load in extra steps, pre and post
    extra_steps = context.mix_release.options[:relexe][:extra_steps]
    extra_steps_pre = extra_steps[phase_name][:pre] || []
    extra_steps_post = extra_steps[phase_name][:post] || []

    mod_list = extra_steps_pre ++ mod_list ++ extra_steps_post

    Enum.reduce(mod_list, context, fn mod, %Context{} = acc ->
      %Context{} = new_context = mod.execute(acc)

      # Halt if `halt` flag was set
      if new_context.halted do
        Log.error(
          :build,
          "Halt requested from phase: #{inspect(phase_name)} in step #{inspect(mod)}"
        )

        exit(1)
      end

      new_context
    end)
  end

  def raise_invalid_target(target) do
    raise "#{target} is not a valid target!"
  end
end

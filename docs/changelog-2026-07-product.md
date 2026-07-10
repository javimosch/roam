
        <div class="feature-card rounded-xl p-6">
          <div class="flex items-start gap-4">
            <div class="w-12 h-12 rounded-lg bg-blue-500/10 flex items-center justify-center flex-shrink-0">
              <span class="text-2xl">🛰️</span>
            </div>
            <div>
              <h3 class="text-xl font-semibold text-white mb-2">Leave a working agent on a remote box</h3>
              <p class="text-white/40 leading-relaxed">Dispatch an autonomous agent to a VM with one command. It replicates itself there (the binary scp's itself), runs detached, and keeps working while you walk away — then you attach back any time to inspect and steer it. One static binary, no Python on the target.</p>
            </div>
          </div>
        </div>

        <div class="feature-card rounded-xl p-6">
          <div class="flex items-start gap-4">
            <div class="w-12 h-12 rounded-lg bg-emerald-500/10 flex items-center justify-center flex-shrink-0">
              <span class="text-2xl">🤖</span>
            </div>
            <div>
              <h3 class="text-xl font-semibold text-white mb-2">A real LLM agent, with tools</h3>
              <p class="text-white/40 leading-relaxed">The worker runs a genuine tool-use loop — read files, write files, run shell — until the goal is met. Works with Claude (Anthropic) or any OpenAI-compatible endpoint such as OpenRouter, so you choose the model. The whole loop is written in machin (MFL), no SDK.</p>
            </div>
          </div>
        </div>

        <div class="feature-card rounded-xl p-6">
          <div class="flex items-start gap-4">
            <div class="w-12 h-12 rounded-lg bg-amber-500/10 flex items-center justify-center flex-shrink-0">
              <span class="text-2xl">🛡️</span>
            </div>
            <div>
              <h3 class="text-xl font-semibold text-white mb-2">A trust layer you can actually walk away from</h3>
              <p class="text-white/40 leading-relaxed">Hard token and iteration budgets freeze a runaway job. Shell is off by default and file access is confined to the job's own working directory. Every model turn, tool call, result, and token cost is journaled — the audit trail you attach to or pull home.</p>
            </div>
          </div>
        </div>

        <div class="feature-card rounded-xl p-6">
          <div class="flex items-start gap-4">
            <div class="w-12 h-12 rounded-lg bg-rose-500/10 flex items-center justify-center flex-shrink-0">
              <span class="text-2xl">✋</span>
            </div>
            <div>
              <h3 class="text-xl font-semibold text-white mb-2">Human-in-the-loop approval — async by design</h3>
              <p class="text-white/40 leading-relaxed">Turn on the confirm-gate and the agent parks on any destructive command (rm, dd, git push, DROP TABLE…) awaiting your approval — approve, deny, or stop, out-of-band. A deny budget auto-halts an agent that keeps trying variants. Since roam is non-interactive, a human and a supervising agent drive the exact same approval interface.</p>
            </div>
          </div>
        </div>

        <div class="feature-card rounded-xl p-6">
          <div class="flex items-start gap-4">
            <div class="w-12 h-12 rounded-lg bg-purple-500/10 flex items-center justify-center flex-shrink-0">
              <span class="text-2xl">🔍</span>
            </div>
            <div>
              <h3 class="text-xl font-semibold text-white mb-2">Don't trust a single "I'm done"</h3>
              <p class="text-white/40 leading-relaxed">An optional goal-verify pass sends every completion to an independent judge that decides from evidence — the real working directory and the action log — not the agent's self-report. A failed check sends the agent back to work; it's fail-open, so a shaky verifier never blocks correct work.</p>
            </div>
          </div>
        </div>

        <div class="feature-card rounded-xl p-6">
          <div class="flex items-start gap-4">
            <div class="w-12 h-12 rounded-lg bg-cyan-500/10 flex items-center justify-center flex-shrink-0">
              <span class="text-2xl">📟</span>
            </div>
            <div>
              <h3 class="text-xl font-semibold text-white mb-2">One interface for humans and agents</h3>
              <p class="text-white/40 leading-relaxed">Every command is one-shot: JSON on stdout, semantic exit codes, no prompts. Status and a live journal stream come back over plain ssh. A person on a laptop and an orchestrating agent use the identical surface — dispatch, watch, steer, approve, stop.</p>
            </div>
          </div>
        </div>

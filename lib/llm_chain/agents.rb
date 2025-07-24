# frozen_string_literal: true

require_relative 'interfaces/agent'
require_relative 'agents/agent_factory'
require_relative 'agents/react_agent'
require_relative 'agents/planner_agent'
require_relative 'agents/composite_agent'

module LLMChain
  module Agents
    # Register built-in agents
    AgentFactory.register(:react, ReActAgent, description: "ReAct agent with reasoning and acting capabilities")
    AgentFactory.register(:planner, PlannerAgent, description: "Planner agent that decomposes complex tasks into atomic steps.")
    AgentFactory.register(:composite, CompositeAgent, description: "Composite agent with planning and execution capabilities for complex multi-step tasks")
    
    # Add more built-in agents here as they are implemented
    # AgentFactory.register(:tool_using, ToolUsingAgent, "Simple tool-using agent")
  end
end 
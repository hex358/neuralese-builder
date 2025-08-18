from typing import Dict, Any
from graph_core import node, Context

@node("InputNode")
def input_node(inputs: Dict[str, Any], props: Dict[str, Any], ctx: Context) -> Dict[str, Any]:
	payload = props.get("value")

	return {"input_out": 0}


@node("NeuronLayer")
def neuron_layer(inputs: Dict[str, Any], props: Dict[str, Any], ctx: Context) -> Dict[str, Any]:
	add = sum(inputs["layer_in"])
	return {"layer_out": props.get("neuron_count", 0) + add}
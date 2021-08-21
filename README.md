# osc-cast

norns mod to broadcast param changes w/ osc.

useful for getting a feedback for external devices controlling norns over osc (m4l devices...).


### usage

set the destination ip address in `PARAMS > osc-cast IP`.

of change of params values, new values will get sent over osc to configured IP address and w/ path `/param/<norns_hostname>/<param_id>`.

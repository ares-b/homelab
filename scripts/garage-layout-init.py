import json, os, sys, time, urllib.request

BASE  = "http://garage.garage.svc.cluster.local:3903"
TOKEN = os.environ["GARAGE_ADMIN_TOKEN"]


def req(base, method, path, body=None):
    data = json.dumps(body).encode() if body is not None else None
    r = urllib.request.Request(
        f"{base}{path}",
        data=data,
        headers={"Authorization": f"Bearer {TOKEN}", "Content-Type": "application/json"},
        method=method,
    )
    return json.loads(urllib.request.urlopen(r, timeout=10).read())


print("waiting for garage admin API...")
while True:
    try:
        req(BASE, "GET", "/v1/health")
        break
    except Exception:
        time.sleep(5)

layout = req(BASE, "GET", "/v2/GetClusterLayout")
if layout.get("version", 0) >= 1:
    print("layout already applied, nothing to do")
    sys.exit(0)

print("connecting cluster nodes via headless DNS...")
specs = []
for i in range(3):
    pod_base = f"http://garage-{i}.garage-headless.garage.svc.cluster.local:3903"
    while True:
        try:
            status = req(pod_base, "GET", "/v2/GetClusterStatus")
            n = status["nodes"][0]
            specs.append(f"{n['id']}@{n['addr']}")
            break
        except Exception:
            time.sleep(5)
req(BASE, "POST", "/v2/ConnectClusterNodes", specs)

print("waiting for 3 nodes...")
while True:
    status = req(BASE, "GET", "/v2/GetClusterStatus")
    nodes = [n for n in status.get("nodes", []) if n.get("isUp")]
    if len(nodes) >= 3:
        break
    print(f"  {len(nodes)}/3 nodes up, retrying...")
    time.sleep(5)

roles = [{"id": n["id"], "zone": "dc1", "capacity": 268435456000, "tags": []} for n in nodes]
req(BASE, "POST", "/v2/UpdateClusterLayout", {"roles": roles})
req(BASE, "POST", "/v2/ApplyClusterLayout", {"version": 1})
print("layout applied successfully")

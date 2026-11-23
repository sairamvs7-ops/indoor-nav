"""Ports the ESP32 firmware's bidirectional Dijkstra (git 693921f, wifi.ino)
exactly, and plain Dijkstra, on the firmware's own graph, and lists the
start/goal pairs where the firmware returned a longer route. Writes
esp32_pairs.json for the film's proof grid."""
import heapq, json
INF = 10**9
N = 29
adj = [[0 if i == j else INF for j in range(N)] for i in range(N)]
def e(u, v, w): adj[u][v] = adj[v][u] = w
for u, v, w in [(13,4,1),(4,5,1),(5,6,1),(6,7,1),(3,2,1),(2,1,1),(1,10,1),(10,12,1),(12,14,1),(13,9,1),(9,11,1),(11,8,1),(8,3,1),(7,10,1),(4,3,1),
                (27,28,1),(28,18,1),(18,19,1),(19,20,1),(20,21,1),(27,23,1),(23,25,1),(25,22,1),(22,17,1),(17,16,1),(16,15,1),(15,24,1),(24,26,1),(21,24,1),(18,17,1),
                (9,23,1),(11,25,2),(10,24,1),(12,26,2)]:
    e(u, v, w)

def esp32(start, end):
    if start == end: return 0
    dF=[INF]*N; dB=[INF]*N; vF=[False]*N; vB=[False]*N
    dF[start]=0; dB[end]=0; inter=-1; best=INF
    for _ in range(1, N):
        uF=-1
        for j in range(1,N):
            if not vF[j] and (uF==-1 or dF[j]<dF[uF]): uF=j
        if uF!=-1 and dF[uF]!=INF:
            vF[uF]=True
            for v in range(1,N):
                if adj[uF][v]!=INF and dF[uF]+adj[uF][v]<dF[v]: dF[v]=dF[uF]+adj[uF][v]
            if vB[uF] and dF[uF]+dB[uF]<best: best=dF[uF]+dB[uF]; inter=uF
        uB=-1
        for j in range(1,N):
            if not vB[j] and (uB==-1 or dB[j]<dB[uB]): uB=j
        if uB!=-1 and dB[uB]!=INF:
            vB[uB]=True
            for v in range(1,N):
                if adj[uB][v]!=INF and dB[uB]+adj[uB][v]<dB[v]: dB[v]=dB[uB]+adj[uB][v]
            if vF[uB] and dF[uB]+dB[uB]<best: best=dF[uB]+dB[uB]; inter=uB
        if inter!=-1 and uF!=-1 and uB!=-1 and dF[uF]+dB[uB]>=best: break
    return best

def plain(s, t):
    d=[INF]*N; d[s]=0; q=[(0,s)]
    while q:
        c,u=heapq.heappop(q)
        if c>d[u]: continue
        for v in range(1,N):
            if adj[u][v]!=INF and u!=v and c+adj[u][v]<d[v]: d[v]=c+adj[u][v]; heapq.heappush(q,(d[v],v))
    return d[t]

nodes = range(1, 29)
bad = [(s, t) for s in nodes for t in nodes if s != t and esp32(s, t) != plain(s, t)]
print("pairs:", 28 * 27, "longer:", len(bad))
print("stairs1->stairs3:", esp32(11, 25), "vs", plain(11, 25))
json.dump({"n": 28, "bad": bad}, open("esp32_pairs.json", "w"))

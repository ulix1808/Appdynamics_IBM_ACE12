import redis.clients.jedis.Jedis;
import redis.clients.jedis.JedisPool;
import redis.clients.jedis.JedisPoolConfig;

/**
 * Prueba minima: classpath = solo los 5 JAR del paquete ace12-jedis-deps.
 * Si compila y ejecuta PING contra Redis, las dependencias runtime estan completas
 * para operaciones basicas (get/set).
 */
public class JedisSmokeTest {
    public static void main(String[] args) {
        String host = args.length > 0 ? args[0] : "localhost";
        int port = args.length > 1 ? Integer.parseInt(args[1]) : 6379;

        JedisPoolConfig cfg = new JedisPoolConfig();
        cfg.setMaxTotal(2);
        try (JedisPool pool = new JedisPool(cfg, host, port)) {
            try (Jedis jedis = pool.getResource()) {
                String pong = jedis.ping();
                jedis.set("ace12:jedis-smoke", "ok");
                String val = jedis.get("ace12:jedis-smoke");
                jedis.del("ace12:jedis-smoke");
                if (!"PONG".equals(pong) || !"ok".equals(val)) {
                    throw new IllegalStateException("Unexpected Redis response: " + pong + " / " + val);
                }
                System.out.println("OK JedisSmokeTest PING=" + pong + " SET/GET=" + val);
            }
        }
    }
}

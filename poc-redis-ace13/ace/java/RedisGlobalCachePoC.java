package com.example.ace.redis.poc;

import com.ibm.broker.javacompute.MbJavaComputeNode;
import com.ibm.broker.plugin.MbElement;
import com.ibm.broker.plugin.MbException;
import com.ibm.broker.plugin.MbMessage;
import com.ibm.broker.plugin.MbMessageAssembly;
import com.ibm.broker.plugin.MbOutputTerminal;

/**
 * Ejemplo JavaCompute para External Redis Global Cache en ACE 13.
 *
 * Uso en el Toolkit:
 *   - Crear JavaCompute node y asignar esta clase (incluir JAR en librería compartida si aplica).
 *   - En el Mapping/Java API, obtener un mapa global pasando el nombre de la Redis Connection policy.
 *
 * Policy: RedisPolicies/RedisConnectionPoC (ver ace/policies/example-redis-connection.policy.xml)
 *
 * Nota: La API exacta de MbGlobalMap puede variar; validar contra la documentación de ACE 13.0.3+.
 */
public class RedisGlobalCachePoC extends MbJavaComputeNode {

    private static final String POLICY_PROJECT = "RedisPolicies";
    private static final String POLICY_NAME = "RedisConnectionPoC";
    private static final String MAP_NAME = "ace13PocCatalog";

    @Override
    public void evaluate(MbMessageAssembly inAssembly) throws MbException {
        MbOutputTerminal out = getOutputTerminal("out");
        MbMessage env = inAssembly.getGlobalEnvironment().getRootElement().getFirstElement();

        String customerId = readCustomerId(env);
        String cacheKey = "customer:" + customerId;

        String cached = getFromRedisGlobalMap(cacheKey);
        if (cached != null) {
            writeResult(env, "CACHE_HIT", cached);
        } else {
            String fromBackend = simulateBackendLookup(customerId);
            putInRedisGlobalMap(cacheKey, fromBackend, 300);
            writeResult(env, "CACHE_MISS", fromBackend);
        }

        MbMessage outMessage = new MbMessage(inAssembly.getMessage());
        MbMessageAssembly outAssembly = new MbMessageAssembly(inAssembly, outMessage);
        out.propagate(outAssembly);
    }

    private String readCustomerId(MbElement env) throws MbException {
        MbElement idElem = env.getFirstElementByPath("/HTTP/Input/QueryString/customerId");
        if (idElem != null) {
            return idElem.getValueAsString();
        }
        return "1001";
    }

    /**
     * Acceso al mapa global respaldado por Redis externo.
     * En ACE 13, al crear el mapa con policy de Redis Connection se usa Redis como backend.
     */
    private String getFromRedisGlobalMap(String key) throws MbException {
        try {
            com.ibm.broker.plugin.MbGlobalMap map = com.ibm.broker.plugin.MbGlobalMap.getGlobalMap(
                MAP_NAME, POLICY_PROJECT, POLICY_NAME);
            Object value = map.get(key);
            return value != null ? value.toString() : null;
        } catch (Exception e) {
            throw new MbException(this, "evaluate", "", "", "", "", "", "", e);
        }
    }

    private void putInRedisGlobalMap(String key, String value, int ttlSeconds) throws MbException {
        try {
            com.ibm.broker.plugin.MbGlobalMap map = com.ibm.broker.plugin.MbGlobalMap.getGlobalMap(
                MAP_NAME, POLICY_PROJECT, POLICY_NAME);
            map.put(key, value, ttlSeconds, com.ibm.broker.plugin.MbGlobalMap.NO_LOCK);
        } catch (Exception e) {
            throw new MbException(this, "evaluate", "", "", "", "", "", "", e);
        }
    }

    private String simulateBackendLookup(String customerId) {
        return "{\"id\":\"" + customerId + "\",\"name\":\"Cliente desde backend\",\"source\":\"CRM\"}";
    }

    private void writeResult(MbElement env, String status, String payload) throws MbException {
        MbElement http = env.createElementAsLastChild(MbElement.TYPE_NAME, "RedisPoC", null);
        http.createElementAsLastChild(MbElement.TYPE_NAME_VALUE, "status", status);
        http.createElementAsLastChild(MbElement.TYPE_NAME_VALUE, "payload", payload);
    }
}

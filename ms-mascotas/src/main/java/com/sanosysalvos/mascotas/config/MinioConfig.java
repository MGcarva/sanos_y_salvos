package com.sanosysalvos.mascotas.config;

import io.minio.BucketExistsArgs;
import io.minio.MakeBucketArgs;
import io.minio.MinioClient;
import io.minio.credentials.IamAwsProvider;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

@Configuration
public class MinioConfig {

    private static final Logger log = LoggerFactory.getLogger(MinioConfig.class);

    @Value("${minio.endpoint}")
    private String endpoint;

    @Value("${minio.access-key:}")
    private String accessKey;

    @Value("${minio.secret-key:}")
    private String secretKey;

    @Value("${minio.bucket}")
    private String bucket;

    @Bean
    public MinioClient minioClient() {
        MinioClient.Builder builder = MinioClient.builder().endpoint(endpoint);

        if (accessKey != null && !accessKey.isBlank()) {
            builder.credentials(accessKey, secretKey);
        } else {
            builder.credentialsProvider(new IamAwsProvider(null, null));
        }

        MinioClient client = builder.build();

        try {
            if (!client.bucketExists(BucketExistsArgs.builder().bucket(bucket).build())) {
                client.makeBucket(MakeBucketArgs.builder().bucket(bucket).build());
            }
        } catch (Exception e) {
            log.warn("Could not verify/create bucket '{}': {}", bucket, e.getMessage());
        }

        return client;
    }
}

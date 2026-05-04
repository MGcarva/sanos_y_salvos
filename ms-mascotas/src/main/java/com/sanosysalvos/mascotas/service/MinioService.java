package com.sanosysalvos.mascotas.service;

import io.minio.*;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import org.springframework.web.multipart.MultipartFile;

import java.io.InputStream;
import java.util.UUID;

@Service
@RequiredArgsConstructor
@Slf4j
public class MinioService {

    private final MinioClient minioClient;

    @Value("${minio.bucket}")
    private String bucket;

    @Value("${minio.endpoint}")
    private String endpoint;

    public String uploadImage(MultipartFile file, UUID reporteId) {
        try {
            String fileName = "reportes/" + reporteId + "/" + file.getOriginalFilename();

            try (InputStream inputStream = file.getInputStream()) {
                minioClient.putObject(PutObjectArgs.builder()
                        .bucket(bucket)
                        .object(fileName)
                        .stream(inputStream, file.getSize(), -1)
                        .contentType(file.getContentType())
                        .build());
            }

            String url = endpoint + "/" + bucket + "/" + fileName;
            log.info("Imagen subida: {}", url);
            return url;
        } catch (Exception e) {
            throw new RuntimeException("Error subiendo imagen a MinIO: " + e.getMessage(), e);
        }
    }
}

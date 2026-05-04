package com.sanosysalvos.coincidencias.config;

import org.springframework.amqp.core.*;
import org.springframework.amqp.rabbit.connection.ConnectionFactory;
import org.springframework.amqp.rabbit.core.RabbitTemplate;
import org.springframework.amqp.support.converter.Jackson2JsonMessageConverter;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

@Configuration
public class RabbitMQConfig {

    public static final String EXCHANGE = "sanos-salvos";
    public static final String COINCIDENCIAS_QUEUE = "coincidencias.queue";
    public static final String NOTIFICATION_QUEUE = "notification.queue";
    public static final String COINCIDENCIAS_ROUTING_KEY = "reporte.geo.completado";
    public static final String NOTIFICATION_ROUTING_KEY = "coincidencia.encontrada";

    @Bean
    public TopicExchange exchange() {
        return new TopicExchange(EXCHANGE);
    }

    @Bean
    public Queue coincidenciasQueue() {
        return QueueBuilder.durable(COINCIDENCIAS_QUEUE)
                .withArgument("x-dead-letter-exchange", EXCHANGE)
                .withArgument("x-dead-letter-routing-key", "coincidencias.dlq")
                .build();
    }

    @Bean
    public Queue notificationQueue() {
        return QueueBuilder.durable(NOTIFICATION_QUEUE).build();
    }

    @Bean
    public Binding coincidenciasBinding(Queue coincidenciasQueue, TopicExchange exchange) {
        return BindingBuilder.bind(coincidenciasQueue).to(exchange).with(COINCIDENCIAS_ROUTING_KEY);
    }

    @Bean
    public Binding notificationBinding(Queue notificationQueue, TopicExchange exchange) {
        return BindingBuilder.bind(notificationQueue).to(exchange).with(NOTIFICATION_ROUTING_KEY);
    }

    @Bean
    public Jackson2JsonMessageConverter jsonMessageConverter() {
        return new Jackson2JsonMessageConverter();
    }

    @Bean
    public RabbitTemplate rabbitTemplate(ConnectionFactory connectionFactory) {
        RabbitTemplate template = new RabbitTemplate(connectionFactory);
        template.setMessageConverter(jsonMessageConverter());
        return template;
    }
}

Although you can terraform an LB, AWS/Kube have a very, very handy controller.

It requires that when an application is launched that it have annotations. For this example, it needs the public facing one and

```yaml
annotations:
    kubernetes.io/ingress.class: alb
    kubernetes.io/role/elb: 1
```

This means you could also describe it with an internal one

```yaml
annotations:
    kubernetes.io/ingress.class: alb
     kubernetes.io/role/internal-elb
```

It also lets each one use an ALB which then automatically routes public or private, depending on annotation, but still leverages the ALB controller/ingress rules.
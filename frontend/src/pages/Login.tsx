import { Link, useNavigate } from 'react-router-dom';
import { api } from '@/lib/api';
import { auth } from '@/state/auth';
import { GoogleSignInButton, AppleSignInButton } from '@/components/SocialAuth';
import { useForm } from '@mantine/form';
import { TextInput, PasswordInput, Button, Paper, Title, Text, Container, Stack, Alert, Divider } from '@mantine/core';
import { useState } from 'react';
import { IconAlertCircle } from '@tabler/icons-react';

export function Login() {
  const [error, setError] = useState<string | null>(null);
  const navigate = useNavigate();

  const form = useForm({
    initialValues: {
      email: '',
      password: '',
    },
    validate: {
      email: (val) => (/^\S+@\S+$/.test(val) ? null : 'Invalid email'),
      password: (val) => (val.length <= 6 ? 'Password should include at least 6 characters' : null),
    },
  });

  const handleSubmit = async (values: typeof form.values) => {
    setError(null);
    try {
      const res = await api.login(values.email, values.password);
      auth.setSession(res);
      navigate('/dashboard');
    } catch (e: any) {
      setError(e.message || 'Login failed');
    }
  };

  return (
    <Container size={420} my={40}>
      <Title ta="center">Welcome back!</Title>
      <Text c="dimmed" size="sm" ta="center" mt={5}>
        Do not have an account yet? <Link to="/register">Create account</Link>
      </Text>

      <Paper withBorder shadow="md" p={30} mt={30} radius="md">
        <form onSubmit={form.onSubmit(handleSubmit)}>
          <Stack gap="md">
            <TextInput
              required
              label="Email"
              placeholder="you@example.com"
              {...form.getInputProps('email')}
            />
            <PasswordInput
              required
              label="Password"
              placeholder="Your password"
              {...form.getInputProps('password')}
            />
            {error && (
              <Alert icon={<IconAlertCircle size="1rem" />} title="Login Error" color="red" variant="light">
                {error}
              </Alert>
            )}
            <Button type="submit" fullWidth mt="xl" loading={form.submitting}>
              Sign in
            </Button>
          </Stack>
        </form>

        <Divider label="or continue with" labelPosition="center" my="lg" />

        <Stack gap="md" mt="md" align="center">
          <GoogleSignInButton />
          <AppleSignInButton />
        </Stack>
      </Paper>
    </Container>
  );
}

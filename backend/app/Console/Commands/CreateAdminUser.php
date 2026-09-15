<?php

namespace App\Console\Commands;

use App\Models\User;
use Illuminate\Console\Command;
use Illuminate\Support\Facades\Validator;

/**
 * Provisions a staff account that can log into the Filament admin panel.
 *
 * A dedicated command rather than the UserResource "create" form (disabled — see
 * UserResource::canCreate()) because every user row requires a real location
 * (base_location/fuzzy_location are NOT NULL, enforced by a SPATIAL index — see the
 * users migration), which doesn't make sense to ask a Filament form to collect for a
 * staff account that isn't a real point on the map.
 */
class CreateAdminUser extends Command
{
    /**
     * @var string
     */
    protected $signature = 'shobuj:create-admin
        {--name= : Full name}
        {--email= : Login email}
        {--password= : Login password (prompted securely if omitted)}
        {--latitude=23.8103 : Placeholder location latitude (defaults to Dhaka)}
        {--longitude=90.4125 : Placeholder location longitude (defaults to Dhaka)}';

    /**
     * @var string
     */
    protected $description = 'Create a staff account with access to the Filament admin panel';

    public function handle(): int
    {
        $name = $this->option('name') ?: $this->ask('Name');
        $email = $this->option('email') ?: $this->ask('Email');
        $password = $this->option('password') ?: $this->secret('Password');

        $validator = Validator::make(
            [
                'name' => $name,
                'email' => $email,
                'password' => $password,
                'latitude' => (float) $this->option('latitude'),
                'longitude' => (float) $this->option('longitude'),
            ],
            [
                'name' => ['required', 'string', 'max:255'],
                'email' => ['required', 'email', 'max:255', 'unique:users,email'],
                'password' => ['required', 'string', 'min:8'],
                'latitude' => ['required', 'numeric', 'between:-90,90'],
                'longitude' => ['required', 'numeric', 'between:-180,180'],
            ],
        );

        if ($validator->fails()) {
            foreach ($validator->errors()->all() as $error) {
                $this->error($error);
            }

            return self::FAILURE;
        }

        $data = $validator->validated();

        $user = new User([
            'name' => $data['name'],
            'email' => $data['email'],
            'password' => $data['password'],
            'is_admin' => true,
            'verified_at' => now(),
        ]);
        $user->setLocation($data['latitude'], $data['longitude']);
        $user->save();

        $this->info("Admin account created: {$user->email}");

        return self::SUCCESS;
    }
}
